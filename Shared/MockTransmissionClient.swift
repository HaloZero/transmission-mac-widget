import Foundation

/// Stands in for `TransmissionRPCClient` — no network, no Keychain, no App
/// Group. Safe to use from Xcode Previews or anywhere the real server isn't
/// reachable.
actor MockTransmissionClient: TransmissionFetching {
    enum Scenario: String {
        case normal    // a realistic mixed set of torrents
        case tooManyTorrents  // a realistic mixed set of too many torrents to display
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
        case .tooManyTorrents:
            return Array(TorrentInfo.fixtures)
        case .empty:
            return []
        case .failure:
            throw TransmissionRPCError.rpc("Mock failure — simulated RPC error")
        }
    }

    func fetchSessionTotals() async throws -> SessionTotals {
        try await Task.sleep(for: simulatedDelay)

        switch scenario {
        case .failure:
            throw TransmissionRPCError.rpc("Mock failure — simulated RPC error")
        case .empty:
            return SessionTotals(downloadedBytes: 0, uploadedBytes: 0)
        case .normal, .tooManyTorrents:
            // A steady pretend trickle tied to wall-clock time, so
            // consecutive polls show a plausible "since last refresh"
            // delta instead of a constant that never actually moves.
            let elapsedSinceEpoch = Date().timeIntervalSince1970
            let downloaded = Int(elapsedSinceEpoch * 50_000)   // ~50 KB/s pretend average
            let uploaded = Int(elapsedSinceEpoch * 12_000)     // ~12 KB/s pretend average
            return SessionTotals(downloadedBytes: downloaded, uploadedBytes: uploaded)
        }
    }
}

#if DEBUG
extension MockTransmissionClient.Scenario {
    /// Force a scenario for local testing by editing this line directly and
    /// rebuilding — no shared storage needed, since the widget is the only
    /// process that reads it. Leave `nil` (the default) for live data; this
    /// entire file is compiled out of Release builds by `#if DEBUG`.
    static let hardcoded: MockTransmissionClient.Scenario? = nil

    /// What's actually forced right now — just `hardcoded` above, checked
    /// wherever data would otherwise be fetched.
    static var forced: MockTransmissionClient.Scenario? { hardcoded }

    /// Runs this scenario through the mock client and returns a ready-to-
    /// display snapshot — the one place that turns "which scenario" into
    /// concrete rows/error text.
    func makeSnapshot() async -> WidgetSnapshot {
        await SnapshotFetcher.fetch(using: MockTransmissionClient(scenario: self))
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
        TorrentInfo(id: 5, name: "Old.Show.S01.Complete", status: .stopped, percentDone: 1.0, rateDownload: 0, rateUpload: 0, eta: -1),
        TorrentInfo(id: 6, name: "Linux.Conf.Talks.2026", status: .downloading, percentDone: 0.07, rateDownload: 320_000, rateUpload: 0, eta: 4200),
        TorrentInfo(id: 7, name: "macOS-27-Installer.dmg", status: .downloading, percentDone: 0.63, rateDownload: 9_400_000, rateUpload: 0, eta: 210),
        TorrentInfo(id: 8, name: "Photography.RAW.Archive.zip", status: .seeding, percentDone: 1.0, rateDownload: 0, rateUpload: 480_000, eta: -1),
        TorrentInfo(id: 9, name: "Retro.Game.Collection.7z", status: .checkWaiting, percentDone: 0.0, rateDownload: 0, rateUpload: 0, eta: -2),
        TorrentInfo(id: 10, name: "Symphony.No.9.Beethoven.flac", status: .downloading, percentDone: 0.95, rateDownload: 210_000, rateUpload: 0, eta: 12),
        TorrentInfo(id: 11, name: "Documentary.Series.S02.Complete", status: .seedWaiting, percentDone: 1.0, rateDownload: 0, rateUpload: 0, eta: -1),
        TorrentInfo(id: 12, name: "Old.Distro.Backup.img", status: .stopped, percentDone: 1.0, rateDownload: 0, rateUpload: 0, eta: -1)
    ]
}
