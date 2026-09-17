import Foundation

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

    /// A plain byte total (no `/s` rate suffix) — for cumulative amounts
    /// like "downloaded since last refresh" rather than a live speed.
    static func formattedBytes(_ bytes: Int) -> String {
        guard bytes > 0 else { return "—" }
        let formatter = ByteCountFormatter()
        formatter.countStyle = .binary
        return formatter.string(fromByteCount: Int64(bytes))
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
