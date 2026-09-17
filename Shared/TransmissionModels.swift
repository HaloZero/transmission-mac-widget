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

    /// Best-effort content icon in the spirit of Transmission's own torrent
    /// list, which shows what kind of thing you're getting (folder, disk
    /// image, archive, media, etc.) rather than a generic file glyph. The
    /// RPC payload here doesn't include a file list, so this infers purely
    /// from the torrent's name — good enough for a quick visual read, not a
    /// substitute for real per-file type info.
    var contentSymbolName: String {
        let extensionToSymbol: [String: String] = [
            "iso": "opticaldisc.fill",
            "img": "opticaldisc.fill",
            "dmg": "externaldrive.fill",
            "pkg": "shippingbox.fill",
            "zip": "doc.zipper",
            "rar": "doc.zipper",
            "7z": "doc.zipper",
            "mp4": "film",
            "mkv": "film",
            "avi": "film",
            "mov": "film",
            "mp3": "music.note",
            "flac": "music.note",
            "wav": "music.note",
            "pdf": "doc.richtext",
            "epub": "book.closed"
        ]

        if let ext = name.split(separator: ".").last.map({ $0.lowercased() }),
           let symbol = extensionToSymbol[ext] {
            return symbol
        }

        // No recognizable file extension usually means a multi-file release
        // (season pack, discography, a magnet link whose metadata hasn't
        // resolved into a single file) — closest visual match is a folder.
        return "folder.fill"
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
