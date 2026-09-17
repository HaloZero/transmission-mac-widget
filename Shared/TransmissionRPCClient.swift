import Foundation

/// Talks to Transmission's RPC endpoint (transmission-daemon / Transmission's
/// built-in web UI server). Reference: https://github.com/transmission/transmission/blob/main/docs/rpc-spec.md
///
/// Transmission requires a rolling `X-Transmission-Session-Id` header. A
/// request without a valid one gets a 409 whose response headers carry the
/// fresh ID — this client caches it and retries once automatically.
///
/// The widget extension is the only thing that ever constructs this (see
/// TorrentProvider) — there's no host-side fetching anymore.
/// `TransmissionRPCError` (which `MockTransmissionClient` also throws) lives
/// in Shared/TransmissionFetching.swift instead, alongside the protocol.
actor TransmissionRPCClient: TransmissionFetching {
    private var sessionID: String?
    private let settings: TransmissionSettings
    private let password: String?
    private let urlSession: URLSession

    init(settings: TransmissionSettings, password: String?, urlSession: URLSession = .shared) {
        self.settings = settings
        self.password = password
        self.urlSession = urlSession
    }

    /// Fetches the torrents with the highest combined I/O, most active first,
    /// capped at `limit` rows — this is what the widget renders.
    func fetchTopTorrents(limit: Int) async throws -> [TorrentInfo] {
        let fields = ["id", "name", "status", "percentDone", "rateDownload", "rateUpload", "eta"]
        let payload: [String: Any] = [
            "method": "torrent-get",
            "arguments": ["fields": fields]
        ]

        let json = try await send(payload)
        guard
            let arguments = json["arguments"] as? [String: Any],
            let torrents = arguments["torrents"] as? [[String: Any]]
        else {
            throw TransmissionRPCError.badResponse
        }

        let parsed: [TorrentInfo] = torrents.compactMap { dict in
            guard
                let id = dict["id"] as? Int,
                let name = dict["name"] as? String,
                let statusRaw = dict["status"] as? Int,
                let status = TorrentStatus(rawValue: statusRaw),
                let percentDone = dict["percentDone"] as? Double
            else { return nil }

            return TorrentInfo(
                id: id,
                name: name,
                status: status,
                percentDone: percentDone,
                rateDownload: dict["rateDownload"] as? Int ?? 0,
                rateUpload: dict["rateUpload"] as? Int ?? 0,
                eta: dict["eta"] as? Int ?? -1
            )
        }

        // Transmission's "status" (downloading/seeding/etc.) just reflects
        // queue state — a torrent can sit at status == .seeding or
        // .downloading with zero throughput (no peers requesting/serving
        // right now). What the widget calls "active" is real, current
        // byte movement, so filter on the rate fields rather than status.
        let moving = parsed.filter { $0.rateDownload > 0 || $0.rateUpload > 0 }

        let sorted = moving.sorted { lhs, rhs in
            let lhsRate = lhs.rateDownload + lhs.rateUpload
            let rhsRate = rhs.rateDownload + rhs.rateUpload
            return lhsRate > rhsRate
        }

        return Array(sorted.prefix(limit))
    }

    /// All-time cumulative download/upload totals from Transmission's own
    /// running counters (`cumulative-stats`, not `current-stats` — the
    /// latter resets whenever the daemon restarts, which would corrupt a
    /// "since last refresh" diff). Callers compute the delta themselves by
    /// comparing against the previous poll's totals.
    func fetchSessionTotals() async throws -> SessionTotals {
        let payload: [String: Any] = ["method": "session-stats"]

        let json = try await send(payload)
        guard
            let arguments = json["arguments"] as? [String: Any],
            let cumulative = arguments["cumulative-stats"] as? [String: Any],
            let downloaded = cumulative["downloadedBytes"] as? Int,
            let uploaded = cumulative["uploadedBytes"] as? Int
        else {
            throw TransmissionRPCError.badResponse
        }

        return SessionTotals(downloadedBytes: downloaded, uploadedBytes: uploaded)
    }

    // MARK: - Transport

    private func send(_ payload: [String: Any]) async throws -> [String: Any] {
        guard let url = settings.baseURL else { throw TransmissionRPCError.noBaseURL }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        applyAuth(to: &request)
        if let sessionID { request.setValue(sessionID, forHTTPHeaderField: "X-Transmission-Session-Id") }

        let (data, response) = try await urlSession.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw TransmissionRPCError.badResponse }

        // Session ID missing or stale — Transmission hands back the current
        // one and expects a single retry.
        if http.statusCode == 409 {
            guard let freshID = http.value(forHTTPHeaderField: "X-Transmission-Session-Id") else {
                throw TransmissionRPCError.http(409)
            }
            sessionID = freshID
            var retry = request
            retry.setValue(freshID, forHTTPHeaderField: "X-Transmission-Session-Id")
            let (retryData, retryResponse) = try await urlSession.data(for: retry)
            guard let retryHTTP = retryResponse as? HTTPURLResponse, retryHTTP.statusCode == 200 else {
                throw TransmissionRPCError.http((retryResponse as? HTTPURLResponse)?.statusCode ?? -1)
            }
            return try decodeRPC(retryData)
        }

        guard http.statusCode == 200 else { throw TransmissionRPCError.http(http.statusCode) }
        return try decodeRPC(data)
    }

    private func decodeRPC(_ data: Data) throws -> [String: Any] {
        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw TransmissionRPCError.badResponse
        }
        if let result = json["result"] as? String, result != "success" {
            throw TransmissionRPCError.rpc(result)
        }
        return json
    }

    private func applyAuth(to request: inout URLRequest) {
        guard !settings.username.isEmpty, let password, !password.isEmpty else { return }
        let raw = "\(settings.username):\(password)"
        guard let data = raw.data(using: .utf8) else { return }
        request.setValue("Basic \(data.base64EncodedString())", forHTTPHeaderField: "Authorization")
    }
}
