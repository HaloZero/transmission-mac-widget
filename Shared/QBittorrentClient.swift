import Foundation

/// Talks to qBittorrent's Web API (`/api/v2/...`).
/// Reference: https://github.com/qbittorrent/qBittorrent/wiki/WebUI-API-(qBittorrent-4.1)
///
/// Unlike Transmission's per-request session header, qBittorrent uses an
/// explicit login step (`/api/v2/auth/login`) that sets a session cookie.
/// This relies on `URLSession`'s default cookie jar to carry that cookie on
/// subsequent requests rather than parsing/attaching `Set-Cookie`/`Cookie`
/// headers by hand — necessary because the cookie's *name* is
/// port-namespaced (e.g. `QBT_SID_9096`), not a fixed `SID`, confirmed
/// against a real server.
actor QBittorrentClient: TorrentFetching {
    private var isAuthenticated = false
    private let settings: QBittorrentSettings
    private let password: String?
    private let urlSession: URLSession

    init(settings: QBittorrentSettings, password: String?, urlSession: URLSession = .shared) {
        self.settings = settings
        self.password = password
        self.urlSession = urlSession
    }

    /// Fetches the torrents with the highest combined I/O, most active
    /// first, capped at `limit` rows — this is what the widget renders.
    func fetchTopTorrents(limit: Int) async throws -> [TorrentInfo] {
        try await authenticateIfNeeded()
        let data = try await get(path: "/api/v2/torrents/info")

        guard let torrents = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
            throw TorrentClientError.badResponse
        }

        let parsed: [TorrentInfo] = torrents.compactMap { dict in
            guard
                let hash = dict["hash"] as? String,
                let name = dict["name"] as? String,
                let stateRaw = dict["state"] as? String,
                let progress = dict["progress"] as? Double
            else { return nil }

            // qBittorrent's sentinel for "unknown/infinite" ETA, confirmed
            // live against a real server — map it onto TorrentInfo's own
            // -1 "unknown" convention instead of carrying the magic number further.
            let eta = dict["eta"] as? Int ?? -1
            return TorrentInfo(
                id: hash,
                name: name,
                status: TorrentStatus(qbittorrentState: stateRaw),
                percentDone: progress,
                rateDownload: dict["dlspeed"] as? Int ?? 0,
                rateUpload: dict["upspeed"] as? Int ?? 0,
                eta: eta >= 8_640_000 ? -1 : eta
            )
        }

        return parsed.topActive(limit: limit)
    }

    /// All-time cumulative download/upload totals from qBittorrent's
    /// `sync/maindata` (`server_state.alltime_dl`/`alltime_ul`) — confirmed
    /// live to be the true all-time counters, distinct from (and larger
    /// than) `dl_info_data`/`up_info_data`, which reset when qBittorrent
    /// restarts. Callers compute the delta themselves by comparing against
    /// the previous poll's totals.
    func fetchSessionTotals() async throws -> SessionTotals {
        try await authenticateIfNeeded()
        let data = try await get(path: "/api/v2/sync/maindata")

        guard
            let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let serverState = json["server_state"] as? [String: Any],
            let downloaded = serverState["alltime_dl"] as? Int,
            let uploaded = serverState["alltime_ul"] as? Int
        else {
            throw TorrentClientError.badResponse
        }

        return SessionTotals(downloadedBytes: downloaded, uploadedBytes: uploaded)
    }

    // MARK: - Transport

    /// Logs in once per client instance (a fresh instance is built every
    /// poll, same cost profile as Transmission's per-poll session-ID
    /// handshake). Success/failure is read from the status code — confirmed
    /// live against a real server that a current qBittorrent build returns
    /// 204 No Content with an empty body on success and 401 on bad
    /// credentials, not the older-docs "200 + body `Ok.`/`Fails.`".
    ///
    /// Note: since this relies on `URLSession`'s shared, process-wide cookie
    /// jar (see the type doc comment), a login with the *wrong* password can
    /// still "succeed" here if a still-valid session cookie from an earlier
    /// *correct* login to the same host is already sitting in that jar —
    /// confirmed live: qBittorrent treats the request as already-authenticated
    /// via the cookie and never actually checks the posted credentials. Only
    /// matters if the widget extension process survives across a credential
    /// change within the cookie's lifetime (an hour, observed); a fresh
    /// process has no such leftover cookie.
    private func authenticateIfNeeded() async throws {
        guard !isAuthenticated else { return }
        guard let url = settings.url(path: "/api/v2/auth/login") else { throw TorrentClientError.noBaseURL }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        var components = URLComponents()
        components.queryItems = [
            URLQueryItem(name: "username", value: settings.username),
            URLQueryItem(name: "password", value: password ?? "")
        ]
        request.httpBody = components.percentEncodedQuery?.data(using: .utf8)

        let (_, response) = try await urlSession.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw TorrentClientError.badResponse }
        guard (200...299).contains(http.statusCode) else { throw TorrentClientError.authenticationFailed }

        isAuthenticated = true
    }

    private func get(path: String) async throws -> Data {
        guard let url = settings.url(path: path) else { throw TorrentClientError.noBaseURL }

        let (data, response) = try await urlSession.data(from: url)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw TorrentClientError.http((response as? HTTPURLResponse)?.statusCode ?? -1)
        }
        return data
    }
}
