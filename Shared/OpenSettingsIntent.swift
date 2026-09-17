import AppIntents
import Foundation

extension Notification.Name {
    static let openSettingsRequested = Notification.Name("com.halozero.transmissionwidget.openSettingsRequested")
}

/// Lets the widget's gear button open the host app's Settings window.
/// `openAppWhenRun` brings TransmissionWidgetHost to the foreground and runs
/// `perform()` inside its process, so the notification is posted and observed
/// in the same app rather than across the widget extension boundary.
struct OpenSettingsIntent: AppIntent {
    static var title: LocalizedStringResource = "Open Transmission Settings"
    static var openAppWhenRun: Bool = true

    @MainActor
    func perform() async throws -> some IntentResult {
        NotificationCenter.default.post(name: .openSettingsRequested, object: nil)
        return .result()
    }
}
