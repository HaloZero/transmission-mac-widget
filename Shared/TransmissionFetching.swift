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
/// RPC client (App/TransmissionRPCClient.swift, host-only) and the mock
/// (widget-visible, for debug scenario previews) both conform, so every
/// view/provider can depend on this instead of `TransmissionRPCClient`
/// directly.
protocol TransmissionFetching: Sendable {
    func fetchTopTorrents(limit: Int) async throws -> [TorrentInfo]
    func fetchSessionTotals() async throws -> SessionTotals
}

/// Shared here (rather than alongside the real client in App/) because
/// `MockTransmissionClient` throws it too, and that file stays widget-visible
/// for debug scenario previews.
enum TransmissionRPCError: LocalizedError {
    case noBaseURL
    case badResponse
    case http(Int)
    case rpc(String)

    var errorDescription: String? {
        switch self {
        case .noBaseURL: return "No Transmission host configured."
        case .badResponse: return "Unexpected response from Transmission."
        case .http(let code): return "Transmission returned HTTP \(code)."
        case .rpc(let message): return message
        }
    }
}
