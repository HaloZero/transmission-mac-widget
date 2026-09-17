import WidgetKit

/// Call this after saving settings or refreshing data, so the widget
/// doesn't wait for its own timeline schedule to pick up the change.
/// Lives here (not App/) so both the host app and the widget extension's
/// own refresh button can call it.
enum WidgetReloader {
    static func reload() {
        WidgetCenter.shared.reloadAllTimelines()
    }
}
