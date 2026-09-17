import Foundation

/// Anything that can answer "what are my top torrents right now" — the real
/// RPC client and the mock both conform, so every view/provider can depend
/// on this instead of `TransmissionRPCClient` directly.
protocol TransmissionFetching: Sendable {
    func fetchTopTorrents(limit: Int) async throws -> [TorrentInfo]
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
