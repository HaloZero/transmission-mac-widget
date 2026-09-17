import WidgetKit

/// Single source of truth for how many torrent rows each widget family
/// shows, and how many to fetch/cache — change a limit here once instead of
/// hunting down every fetch call and view cap that needs to agree with it.
enum Constants {
    static let maxRows: [WidgetFamily: Int] = [
        .systemMedium: 3,
        .systemLarge: 6
    ]

    private static let defaultMaxRows = 6

    static func maxRows(for family: WidgetFamily) -> Int {
        maxRows[family] ?? defaultMaxRows
    }

    /// How many torrents to fetch and cache. Must be at least the largest
    /// family's row count in `maxRows`, or that family would run out of
    /// data to show.
    static let fetchLimit = maxRows.values.max() ?? defaultMaxRows

    /// How often the host app polls Transmission and refreshes the shared
    /// cache while it's running. Not subject to WidgetKit's reload budget —
    /// it's a normal background loop, not a widget reload — so it can run
    /// far more often than `widgetReloadInterval`.
    static let hostPollInterval: TimeInterval = 90

    /// How often the host app asks WidgetKit to reload the widget's
    /// timeline. WidgetKit enforces a system-wide daily reload budget per
    /// widget kind that applies no matter who triggers the reload — keep
    /// this modest so calls aren't silently dropped.
    static let widgetReloadInterval: TimeInterval = 15 * 60

    /// If the cached snapshot is older than this, the host app's poller
    /// isn't keeping it fresh (not running, not a login item yet, just
    /// rebooted, etc.) — the widget's own TimelineProvider falls back to
    /// fetching directly rather than displaying indefinitely stale data.
    static let cacheStalenessThreshold: TimeInterval = widgetReloadInterval * 2
}
