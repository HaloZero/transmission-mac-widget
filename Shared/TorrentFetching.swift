import Foundation

/// All-time cumulative byte totals — Transmission's `session-stats` RPC
/// (`cumulative-stats`) or qBittorrent's `sync/maindata`
/// (`server_state.alltime_dl`/`alltime_ul`) — the daemon's own running
/// counters, unaffected by which torrents happen to be in a filtered/top-N
/// list or by a daemon restart, so diffing two of these is a true "since
/// last poll" delta.
struct SessionTotals: Sendable {
    var downloadedBytes: Int
    var uploadedBytes: Int
}

/// Anything that can answer "what are my top torrents right now" — the real
/// clients (`TransmissionRPCClient`, `QBittorrentClient`, both host-only)
/// and the mock (widget-visible, for debug scenario previews) all conform,
/// so every view/provider can depend on this instead of a concrete client
/// type directly.
protocol TorrentFetching: Sendable {
    func fetchTopTorrents(limit: Int) async throws -> [TorrentInfo]
    func fetchSessionTotals() async throws -> SessionTotals
}

/// Shared here (rather than alongside one real client) because every client
/// — real or mock — throws it.
enum TorrentClientError: LocalizedError {
    case noBaseURL
    case badResponse
    case http(Int)
    case rpc(String)
    case authenticationFailed

    var errorDescription: String? {
        switch self {
        case .noBaseURL: return "No server configured."
        case .badResponse: return "Unexpected response from the server."
        case .http(let code): return "Server returned HTTP \(code)."
        case .rpc(let message): return message
        case .authenticationFailed: return "Authentication failed — check your username and password."
        }
    }
}

extension Array where Element == TorrentInfo {
    /// Most active first (by combined ↓+↑ rate), moving torrents only,
    /// capped at `limit` — the selection every backend's `fetchTopTorrents`
    /// needs, factored out so each client only has to map its own JSON onto
    /// `TorrentInfo` and let this do the rest.
    ///
    /// A torrent's reported status (downloading/seeding/etc.) just reflects
    /// queue state — it can sit at "seeding" or "downloading" with zero
    /// throughput (no peers requesting/serving right now). What the widget
    /// calls "active" is real, current byte movement, so this filters on the
    /// rate fields rather than status.
    func topActive(limit: Int) -> [TorrentInfo] {
        let moving = filter { $0.rateDownload > 0 || $0.rateUpload > 0 }
        let sorted = moving.sorted { lhs, rhs in
            (lhs.rateDownload + lhs.rateUpload) > (rhs.rateDownload + rhs.rateUpload)
        }
        return Array(sorted.prefix(limit))
    }
}
