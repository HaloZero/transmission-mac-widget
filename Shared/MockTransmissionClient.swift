import Foundation

/// Stands in for `TransmissionRPCClient` — no network, no Keychain, no App
/// Group. Safe to use from Xcode Previews or anywhere the real server isn't
/// reachable.
actor MockTransmissionClient: TransmissionFetching {
    enum Scenario: String {
        case normal    // a realistic mixed set of torrents
        case empty     // nothing active — exercises the "No active torrents" state
        case failure   // simulates an RPC error — exercises the error state
    }

    private let scenario: Scenario
    private let simulatedDelay: Duration

    init(scenario: Scenario = .normal, simulatedDelay: Duration = .milliseconds(300)) {
        self.scenario = scenario
        self.simulatedDelay = simulatedDelay
    }

    func fetchTopTorrents(limit: Int) async throws -> [TorrentInfo] {
        try await Task.sleep(for: simulatedDelay)

        switch scenario {
        case .normal:
            return Array(TorrentInfo.fixtures.prefix(limit))
        case .empty:
            return []
        case .failure:
            throw TransmissionRPCError.rpc("Mock failure — simulated RPC error")
        }
    }
}

#if DEBUG
extension MockTransmissionClient.Scenario {
    /// Force a scenario for local testing by editing this line directly and
    /// rebuilding — no scheme or environment-variable configuration needed.
    /// The host app and the widget extension both compile this same literal
    /// into their own binary, so they always agree without any cross-process
    /// state. Leave `nil` (the default) for live data; this entire file is
    /// compiled out of Release builds by `#if DEBUG`.
    static let hardcoded: MockTransmissionClient.Scenario? = nil

    private static let forcedKey = "debugForcedScenario"

    /// What's actually forced right now, checked explicitly wherever data
    /// would otherwise be fetched: `hardcoded` above if set, otherwise
    /// whatever the menu bar's "Debug: Load Scenario" picker last chose.
    /// `nil` means live data. A single computed answer instead of a
    /// separate lock flag that can drift from what's actually cached.
    static var forced: MockTransmissionClient.Scenario? {
        get { hardcoded ?? AppGroup.defaults.string(forKey: forcedKey).flatMap(Self.init(rawValue:)) }
        set { AppGroup.defaults.set(newValue?.rawValue, forKey: forcedKey) }
    }

    /// Runs this scenario through the mock client and returns a ready-to-
    /// save snapshot — the one place that turns "which scenario" into
    /// concrete rows/error text, shared by the host app and the widget.
    func makeSnapshot() async -> WidgetSnapshot {
        let client = MockTransmissionClient(scenario: self)
        do {
            let rows = try await client.fetchTopTorrents(limit: 4)
            return WidgetSnapshot(rows: rows, fetchedAt: Date(), errorMessage: nil)
        } catch {
            return WidgetSnapshot(rows: [], fetchedAt: Date(), errorMessage: error.localizedDescription)
        }
    }
}
#endif

extension TorrentInfo {
    /// Covers every status the UI branches on (downloading, seeding,
    /// checking, stopped) so a Preview actually exercises the icons and
    /// progress bars instead of just one happy-path row.
    static let fixtures: [TorrentInfo] = [
        TorrentInfo(id: 1, name: "ubuntu-24.04.1-desktop-amd64.iso", status: .downloading, percentDone: 0.42, rateDownload: 6_800_000, rateUpload: 45_000, eta: 640),
        TorrentInfo(id: 2, name: "Some.Documentary.2025.1080p.WEB", status: .downloading, percentDone: 0.88, rateDownload: 1_200_000, rateUpload: 0, eta: 95),
        TorrentInfo(id: 3, name: "Podcast.Archive.Vol03", status: .seeding, percentDone: 1.0, rateDownload: 0, rateUpload: 950_000, eta: -1),
        TorrentInfo(id: 4, name: "debian-12.6.0-amd64-netinst.iso", status: .checking, percentDone: 0.15, rateDownload: 0, rateUpload: 0, eta: -2),
        TorrentInfo(id: 5, name: "Old.Show.S01.Complete", status: .stopped, percentDone: 1.0, rateDownload: 0, rateUpload: 0, eta: -1)
    ]
}
