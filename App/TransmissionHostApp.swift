import SwiftUI
import WidgetKit

@main
struct TransmissionHostApp: App {
    var body: some Scene {
        // A menu-bar-only app avoids a Dock icon / window for something
        // that's mostly here to configure the widget and force refreshes.
        // Set LSUIElement = YES in Info.plist to hide the Dock icon.
        MenuBarExtra("Transmission", image: "MenuBarIcon") {
            ContentView()
                .frame(width: 340)
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView()
                .frame(width: 420)
        }
    }
}

/// Call this after saving settings, or on a manual refresh, so the widget
/// doesn't wait for its own timeline schedule to pick up the change.
func reloadWidget() {
    WidgetCenter.shared.reloadAllTimelines()
}
