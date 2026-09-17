import AppIntents

/// Bound to the widget's own refresh button. WidgetKit automatically
/// reloads *this* widget's timeline once `perform()` returns, which re-runs
/// `TorrentProvider.timeline(for:in:)` — that's what does the actual fetch,
/// so this intent itself has nothing to do.
struct RefreshTorrentsIntent: AppIntent {
    static var title: LocalizedStringResource = "Refresh Torrents"
    static var description = IntentDescription("Fetches the latest torrent status immediately.")
    static var openAppWhenRun: Bool = false

    func perform() async throws -> some IntentResult {
        .result()
    }
}
