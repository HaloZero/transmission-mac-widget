import Foundation

/// The single place that decides real vs. mock — ContentView, SettingsView,
/// and the widget's TimelineProvider all call this instead of constructing
/// `TransmissionRPCClient` themselves.
enum TransmissionClientFactory {
    static func make() -> any TransmissionFetching {
        if DevEnvironment.shouldUseMockData {
            return MockTransmissionClient(scenario: DevEnvironment.mockScenario)
        }
        let settings = TransmissionSettings.load()
        let password = KeychainHelper.loadPassword()
        return TransmissionRPCClient(settings: settings, password: password)
    }
}
