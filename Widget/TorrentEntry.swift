import WidgetKit

struct TorrentEntry: TimelineEntry {
    let date: Date
    let rows: [TorrentInfo]
    let errorMessage: String?
}
