import Foundation

/// Subset of Transmission's torrent-status values we care about for display.
/// Full list: https://github.com/transmission/transmission/blob/main/docs/rpc-spec.md
enum TorrentStatus: Int, Codable {
    case stopped = 0
    case checkWaiting = 1
    case checking = 2
    case downloadWaiting = 3
    case downloading = 4
    case seedWaiting = 5
    case seeding = 6

    var symbolName: String {
        switch self {
        case .stopped: return "pause.circle"
        case .checkWaiting, .checking: return "magnifyingglass.circle"
        case .downloadWaiting, .downloading: return "arrow.down.circle.fill"
        case .seedWaiting, .seeding: return "arrow.up.circle.fill"
        }
    }

    var statusLabel: String {
        switch self {
        case .stopped: return "Paused"
        case .checkWaiting, .checking: return "Checking"
        case .downloadWaiting: return "Waiting"
        case .downloading: return "Downloading"
        case .seedWaiting: return "Waiting"
        case .seeding: return "Seeding"
        }
    }
}
