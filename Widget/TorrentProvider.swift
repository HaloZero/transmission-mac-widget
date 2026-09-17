import WidgetKit

struct TorrentProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> TorrentEntry {
        TorrentEntry(date: Date(), rows: [], errorMessage: nil)
    }

    func snapshot(for configuration: TransmissionWidgetConfigurationIntent, in context: Context) async -> TorrentEntry {
        // Widget gallery / quick preview — use whatever's cached locally,
        // no network call, so the gallery renders instantly.
        let cached = WidgetSnapshot.load()
        return TorrentEntry(date: Date(), rows: Array(cached.rows.prefix(Constants.fetchLimit)), errorMessage: cached.errorMessage)
    }

    func timeline(for configuration: TransmissionWidgetConfigurationIntent, in context: Context) async -> Timeline<TorrentEntry> {
        #if DEBUG
        if let forced = MockTransmissionClient.Scenario.forced {
            // A scenario is forced (edit MockTransmissionClient.Scenario.hardcoded
            // and rebuild) — serve it as-is instead of a real fetch.
            let snapshot = await forced.makeSnapshot()
            snapshot.save()
            let entry = TorrentEntry(date: snapshot.fetchedAt, rows: snapshot.rows, errorMessage: snapshot.errorMessage)
            return Timeline(entries: [entry], policy: .never)
        }
        #endif

        let client = TransmissionRPCClient(
            settings: configuration.settings,
            password: configuration.password.isEmpty ? nil : configuration.password
        )
        let snapshot = await SnapshotFetcher.fetch(using: client)
        if snapshot.errorMessage == nil {
            snapshot.save()
        }

        let entry = TorrentEntry(date: snapshot.fetchedAt, rows: snapshot.rows, errorMessage: snapshot.errorMessage)
        let nextCheck = Date().addingTimeInterval(Constants.refreshInterval)
        return Timeline(entries: [entry], policy: .after(nextCheck))
    }
}
