import Foundation

/// Fetches torrents + session totals and returns a ready-to-save snapshot —
/// the single fetch/diff code path shared by the host app's manual refresh,
/// its background poller, and the widget's fallback fetch, so "since last
/// refresh" is computed the same way everywhere.
enum SnapshotFetcher {
    /// On failure, carries the previous cached rows/totals forward with the
    /// new error message rather than losing them.
    static func fetch(using client: any TransmissionFetching) async -> WidgetSnapshot {
        let previous = WidgetSnapshot.load()
        do {
            async let rowsTask = client.fetchTopTorrents(limit: Constants.fetchLimit)
            async let totalsTask = client.fetchSessionTotals()
            let (rows, totals) = try await (rowsTask, totalsTask)

            // Zero on the very first poll ever — there's no prior total to
            // diff against, and diffing from zero would report the entire
            // all-time total as "since last refresh". Also floor at zero in
            // case the daemon restarted and its counters reset lower.
            let hasPrior = previous.cumulativeDownloaded > 0 || previous.cumulativeUploaded > 0
            let downloadedDelta = hasPrior ? max(0, totals.downloadedBytes - previous.cumulativeDownloaded) : 0
            let uploadedDelta = hasPrior ? max(0, totals.uploadedBytes - previous.cumulativeUploaded) : 0

            return WidgetSnapshot(
                rows: rows,
                fetchedAt: Date(),
                errorMessage: nil,
                cumulativeDownloaded: totals.downloadedBytes,
                cumulativeUploaded: totals.uploadedBytes,
                downloadedSinceLastRefresh: downloadedDelta,
                uploadedSinceLastRefresh: uploadedDelta
            )
        } catch {
            return WidgetSnapshot(
                rows: previous.rows,
                fetchedAt: previous.fetchedAt,
                errorMessage: error.localizedDescription,
                cumulativeDownloaded: previous.cumulativeDownloaded,
                cumulativeUploaded: previous.cumulativeUploaded,
                downloadedSinceLastRefresh: 0,
                uploadedSinceLastRefresh: 0
            )
        }
    }
}
