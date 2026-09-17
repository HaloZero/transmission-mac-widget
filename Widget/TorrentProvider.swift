import WidgetKit

struct TorrentProvider: TimelineProvider {
    func placeholder(in context: Context) -> TorrentEntry {
        TorrentEntry(date: Date(), rows: [], errorMessage: nil)
    }

    func getSnapshot(in context: Context, completion: @escaping (TorrentEntry) -> Void) {
        // Widget gallery / quick preview — use whatever the app last cached,
        // no network call, so the gallery renders instantly.
        let cached = WidgetSnapshot.load()
        completion(TorrentEntry(date: Date(), rows: Array(cached.rows.prefix(4)), errorMessage: cached.errorMessage))
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
                let entry = TorrentEntry(date: Date(), rows: snapshot.rows, errorMessage: snapshot.errorMessage)
                completion(Timeline(entries: [entry], policy: .never))
                return
            }
            #endif

            let client = makeTransmissionClient()

            var entry: TorrentEntry
            do {
                let rows = try await client.fetchTopTorrents(limit: 4)
                WidgetSnapshot(rows: rows, fetchedAt: Date(), errorMessage: nil).save()
                entry = TorrentEntry(date: Date(), rows: rows, errorMessage: nil)
            } catch {
                // Fall back to the last good snapshot rather than showing a
                // blank widget the moment the Mac mini is asleep or offline.
                let cached = WidgetSnapshot.load()
                entry = TorrentEntry(date: Date(), rows: cached.rows, errorMessage: error.localizedDescription)
            }

            // Refresh every 5 minutes — frequent enough to feel live without
            // burning the widget's limited refresh budget. Adjust to taste.
            let nextRefresh = Calendar.current.date(byAdding: .minute, value: 5, to: Date()) ?? Date().addingTimeInterval(300)
            completion(Timeline(entries: [entry], policy: .after(nextRefresh)))
        }
    }
}
