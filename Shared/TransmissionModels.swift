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
}

struct TorrentInfo: Codable, Identifiable, Equatable {
    let id: Int
    let name: String
    let status: TorrentStatus
    let percentDone: Double   // 0.0 ... 1.0
    let rateDownload: Int     // bytes/sec
    let rateUpload: Int       // bytes/sec
    let eta: Int              // seconds, -1 = unknown, -2 = unavailable

    var progressLabel: String {
        String(format: "%.0f%%", percentDone * 100)
    }

    static func formattedRate(_ bytesPerSecond: Int) -> String {
        guard bytesPerSecond > 0 else { return "—" }
        let formatter = ByteCountFormatter()
        formatter.countStyle = .binary
        return formatter.string(fromByteCount: Int64(bytesPerSecond)) + "/s"
    }
}

/// What gets cached into the App Group so the widget has something to show
/// even before its own network refresh completes, and so the host app's
/// last-known state matches the widget.
struct WidgetSnapshot: Codable {
    var rows: [TorrentInfo]
    var fetchedAt: Date
    var errorMessage: String?

    static let empty = WidgetSnapshot(rows: [], fetchedAt: .distantPast, errorMessage: nil)

    private static let key = "widgetSnapshot"

    static func load() -> WidgetSnapshot {
        guard let data = AppGroup.defaults.data(forKey: key),
              let decoded = try? JSONDecoder().decode(WidgetSnapshot.self, from: data) else {
            return .empty
        }
        return decoded
    }

    func save() {
        if let data = try? JSONEncoder().encode(self) {
            AppGroup.defaults.set(data, forKey: WidgetSnapshot.key)
        }
    }
}
