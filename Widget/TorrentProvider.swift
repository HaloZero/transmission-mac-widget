import WidgetKit

struct TorrentProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> TorrentEntry {
        TorrentEntry(date: Date(), rows: [], errorMessage: nil)
    }

    func snapshot(for configuration: TorrentWidgetConfigurationIntent, in context: Context) async -> TorrentEntry {
        // Widget gallery / quick preview — use whatever's cached locally,
        // no network call, so the gallery renders instantly.
        let cached = WidgetSnapshot.load(cacheKey: configuration.cacheKey)
        return TorrentEntry(date: Date(), rows: Array(cached.rows.prefix(Constants.fetchLimit)), errorMessage: cached.errorMessage)
    }

    func timeline(for configuration: TorrentWidgetConfigurationIntent, in context: Context) async -> Timeline<TorrentEntry> {
        #if DEBUG
        if let forced = MockTorrentClient.Scenario.forced {
            // A scenario is forced (edit MockTorrentClient.Scenario.hardcoded
            // and rebuild) — serve it as-is instead of a real fetch.
            let snapshot = await forced.makeSnapshot(cacheKey: configuration.cacheKey)
            snapshot.save(cacheKey: configuration.cacheKey)
            let entry = TorrentEntry(date: snapshot.fetchedAt, rows: snapshot.rows, errorMessage: snapshot.errorMessage)
            return Timeline(entries: [entry], policy: .never)
        }
        #endif

        let password = configuration.password.isEmpty ? nil : configuration.password
        let client: any TorrentFetching
        switch configuration.backend {
        case .transmission:
            client = TransmissionRPCClient(settings: configuration.transmissionSettings, password: password)
        case .qbittorrent:
            client = QBittorrentClient(settings: configuration.qbittorrentSettings, password: password)
        }
        let snapshot = await SnapshotFetcher.fetch(using: client, cacheKey: configuration.cacheKey)
        if snapshot.errorMessage == nil {
            snapshot.save(cacheKey: configuration.cacheKey)
        }

        let entry = TorrentEntry(date: snapshot.fetchedAt, rows: snapshot.rows, errorMessage: snapshot.errorMessage)
        let nextCheck = Date().addingTimeInterval(Constants.refreshInterval)
        return Timeline(entries: [entry], policy: .after(nextCheck))
    }
}
