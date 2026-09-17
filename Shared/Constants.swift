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
}
