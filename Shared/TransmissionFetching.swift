import Foundation

/// All-time cumulative byte totals, straight from Transmission's
/// `session-stats` RPC (`cumulative-stats`) — the daemon's own running
/// counters, unaffected by which torrents happen to be in a filtered/top-N
/// list, so diffing two of these is a true "since last poll" delta.
struct SessionTotals: Sendable {
    var downloadedBytes: Int
    var uploadedBytes: Int
}

/// Anything that can answer "what are my top torrents right now" — the real
/// RPC client and the mock both conform, so every view/provider can depend
/// on this instead of `TransmissionRPCClient` directly.
protocol TransmissionFetching: Sendable {
    func fetchTopTorrents(limit: Int) async throws -> [TorrentInfo]
    func fetchSessionTotals() async throws -> SessionTotals
}

extension TransmissionRPCClient: TransmissionFetching {}
