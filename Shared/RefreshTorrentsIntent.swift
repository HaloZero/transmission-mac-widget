import AppIntents

/// Lets the widget's own refresh button fetch immediately, without waiting
/// for `TorrentProvider`'s cache/staleness schedule. Unlike
/// `OpenSettingsIntent`, this deliberately does *not* set `openAppWhenRun`
/// — there's nothing to show the user, so `perform()` runs directly in
/// whichever process WidgetKit invokes it in (normally the widget
/// extension) rather than foregrounding the host app just to refresh data.
struct RefreshTorrentsIntent: AppIntent {
    static var title: LocalizedStringResource = "Refresh Torrents"
    static var description = IntentDescription("Fetches the latest torrent status immediately.")
    static var openAppWhenRun: Bool = false

    func perform() async throws -> some IntentResult {
        #if DEBUG
        if let forced = MockTransmissionClient.Scenario.forced {
            // A scenario is forced — re-serve it rather than racing it with
            // a real fetch that would immediately overwrite it.
            let snapshot = await forced.makeSnapshot()
            snapshot.save()
            WidgetReloader.reload()
            return .result()
        }
        #endif

        let snapshot = await SnapshotFetcher.fetch(using: TransmissionClientFactory.make())
        if snapshot.errorMessage == nil {
            snapshot.save()
        }
        WidgetReloader.reload()
        return .result()
    }
}
