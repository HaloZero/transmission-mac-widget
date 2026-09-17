import WidgetKit

struct TorrentProvider: TimelineProvider {
    func placeholder(in context: Context) -> TorrentEntry {
        TorrentEntry(date: Date(), rows: [], errorMessage: nil)
    }

    func getSnapshot(in context: Context, completion: @escaping (TorrentEntry) -> Void) {
        // Widget gallery / quick preview — use whatever the app last cached,
        // no network call, so the gallery renders instantly.
        let cached = WidgetSnapshot.load()
        completion(TorrentEntry(date: Date(), rows: Array(cached.rows.prefix(Constants.fetchLimit)), errorMessage: cached.errorMessage))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<TorrentEntry>) -> Void) {
        Task {
            #if DEBUG
            if let forced = MockTransmissionClient.Scenario.forced {
                // A scenario is forced (hardcoded constant or the host app's
                // debug menu) — serve it as-is instead of racing it with a
                // real fetch that would immediately overwrite it.
                let snapshot = await forced.makeSnapshot()
                snapshot.save()
                let entry = TorrentEntry(date: snapshot.fetchedAt, rows: snapshot.rows, errorMessage: snapshot.errorMessage)
                completion(Timeline(entries: [entry], policy: .never))
                return
            }
            #endif

            let cached = WidgetSnapshot.load()
            let cacheAge = Date().timeIntervalSince(cached.fetchedAt)

            let entry: TorrentEntry
            if cacheAge < Constants.cacheStalenessThreshold {
                // The host app's background poller is keeping this fresh —
                // just display it instead of doing a redundant fetch of our
                // own inside the widget extension.
                entry = TorrentEntry(date: cached.fetchedAt, rows: cached.rows, errorMessage: cached.errorMessage)
            } else {
                // Cache is stale — the host app likely isn't running (not a
                // login item yet, just rebooted, etc.). Fall back to
                // fetching directly so the widget doesn't stay stuck.
                let fresh = await SnapshotFetcher.fetch(using: TransmissionClientFactory.make())
                if fresh.errorMessage == nil {
                    fresh.save()
                }
                entry = TorrentEntry(date: fresh.fetchedAt, rows: fresh.rows, errorMessage: fresh.errorMessage)
            }

            // Ask WidgetKit to check back as often as new data could
            // possibly exist (hostPollInterval), not our own conservative
            // widgetReloadInterval guess — the cache-hit path above is a
            // free local read, so there's no cost to asking more often and
            // letting the system's own budget/visibility throttling decide
            // the real-world cadence, instead of us pre-emptively rationing
            // to a fixed slow interval. Asking for shorter than
            // hostPollInterval would just re-serve the same cached data,
            // since that's how often it can actually change.
            let nextCheck = Date().addingTimeInterval(Constants.hostPollInterval)
            completion(Timeline(entries: [entry], policy: .after(nextCheck)))
        }
    }
}
