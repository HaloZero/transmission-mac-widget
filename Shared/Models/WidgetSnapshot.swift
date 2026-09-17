import Foundation

/// Cached locally (plain UserDefaults.standard — the widget is the only
/// process that ever reads or writes this) so the widget has something to
/// show instantly in the gallery/preview, and so a transient fetch failure
/// can fall back to the last-good rows instead of going blank.
struct WidgetSnapshot: Codable {
    var rows: [TorrentInfo]
    var fetchedAt: Date
    var errorMessage: String?

    /// All-time cumulative totals as of this snapshot's fetch, from
    /// Transmission's `session-stats` RPC — used to compute the *Since*
    /// fields on the next poll. Not something anyone displays directly.
    var cumulativeDownloaded: Int = 0
    var cumulativeUploaded: Int = 0

    /// Bytes moved between this snapshot and the previous one. Zero on the
    /// very first poll ever (no prior total to diff against) rather than
    /// the misleading "entire all-time total" that a naive diff-from-zero
    /// would produce.
    var downloadedSinceLastRefresh: Int = 0
    var uploadedSinceLastRefresh: Int = 0

    static let empty = WidgetSnapshot(rows: [], fetchedAt: .distantPast, errorMessage: nil)

    private static let key = "widgetSnapshot"

    static func load() -> WidgetSnapshot {
        guard let data = UserDefaults.standard.data(forKey: key),
              let decoded = try? JSONDecoder().decode(WidgetSnapshot.self, from: data) else {
            return .empty
        }
        return decoded
    }

    func save() {
        if let data = try? JSONEncoder().encode(self) {
            UserDefaults.standard.set(data, forKey: WidgetSnapshot.key)
        }
    }
}
