import SwiftUI

@main
struct TransmissionHostApp: App {
    var body: some Scene {
        // A menu-bar-only app avoids a Dock icon / window for something
        // that's now just a way to quit — the widget extension does
        // everything else (fetching, caching, configuration) on its own.
        MenuBarExtra(menuBarTitle, image: "MenuBarIcon") {
            ContentView()
        }
        .menuBarExtraStyle(.window)
    }

    private var menuBarTitle: String {
        #if DEBUG
        "Transmission (Debug)"
        #else
        "Transmission"
        #endif
    }
}
