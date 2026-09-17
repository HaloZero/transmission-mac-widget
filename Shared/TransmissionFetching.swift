import Foundation

/// All-time cumulative byte totals, straight from Transmission's
/// `session-stats` RPC (`cumulative-stats`) — the daemon's own running
/// counters, unaffected by which torrents happen to be in a filtered/top-N
/// list, so diffing two of these is a true "since last poll" delta.
struct SessionTotals: Sendable {
    var downloadedBytes: Int
    var uploadedBytes: Int
}

/// Anything that can answer "what are my top torrents right now" — the real
/// RPC client and the mock both conform, so every view/provider can depend
/// on this instead of `TransmissionRPCClient` directly.
protocol TransmissionFetching: Sendable {
    func fetchTopTorrents(limit: Int) async throws -> [TorrentInfo]
    func fetchSessionTotals() async throws -> SessionTotals
}

extension TransmissionRPCClient: TransmissionFetching {}

/// Controls when mock data is used instead of a real network call.
enum DevEnvironment {
    /// True whenever this process is an Xcode Preview render. Previews run
    /// in a lightweight process that usually lacks this app's entitlements
    /// (no Keychain access group, sometimes no App Group) and shouldn't be
    /// blocked on m1mediaserver being reachable — that's what made the
    /// canvas hang/error out before this existed.
    static var isXcodePreview: Bool {
        ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"
    }

    /// Set `TRANSMISSION_USE_MOCK_DATA=1` in the scheme's Run → Arguments →
    /// Environment Variables to develop the app or widget UI without the
    /// Mac mini reachable (e.g. off the tailnet). Optionally pair with
    /// `TRANSMISSION_MOCK_SCENARIO=empty` or `=failure` to preview those
    /// states deliberately instead of the happy path.
    static var forcesMockData: Bool {
        #if DEBUG
            return true
        #else
            return false
        #endif
    }

    static var mockScenario: MockTransmissionClient.Scenario {
        return .normal
    }

    static var shouldUseMockData: Bool {
        isXcodePreview || forcesMockData
    }
}

/// The single place that decides real vs. mock — ContentView, SettingsView,
/// and the widget's TimelineProvider all call this instead of constructing
/// `TransmissionRPCClient` themselves.
func makeTransmissionClient() -> any TransmissionFetching {
    if DevEnvironment.shouldUseMockData {
        return MockTransmissionClient(scenario: DevEnvironment.mockScenario)
    }
    let settings = TransmissionSettings.load()
    let password = KeychainHelper.loadPassword()
    return TransmissionRPCClient(settings: settings, password: password)
}

/// Fetches torrents + session totals and returns a ready-to-save snapshot —
/// the single fetch/diff code path shared by the host app's manual refresh,
/// its background poller, and the widget's fallback fetch, so "since last
/// refresh" is computed the same way everywhere. On failure, carries the
/// previous cached rows/totals forward with the new error message rather
/// than losing them.
func fetchSnapshot(using client: any TransmissionFetching) async -> WidgetSnapshot {
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
