import SwiftUI
import WidgetKit

@main
struct TransmissionHostApp: App {
    init() {
        BackgroundRefresher.shared.start()
    }

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

/// Keeps the shared cache fresh while the host app is running, independent
/// of whether the menu bar dropdown is open. This is a plain background
/// loop, not a widget reload, so it isn't subject to WidgetKit's daily
/// reload budget and can poll far more often than we'd ever want to call
/// `reloadWidget()` — see `Constants.hostPollInterval` vs
/// `Constants.widgetReloadInterval`.
@MainActor
final class BackgroundRefresher {
    static let shared = BackgroundRefresher()

    private var pollTask: Task<Void, Never>?
    private var lastReload = Date.distantPast

    private init() {}

    func start() {
        guard pollTask == nil else { return }
        pollTask = Task {
            while !Task.isCancelled {
                await tick()
                try? await Task.sleep(for: .seconds(Constants.hostPollInterval))
            }
        }
    }

    private func tick() async {
        #if DEBUG
        // A debug scenario is forced — don't let the poller race it with a
        // real fetch that would immediately overwrite it.
        guard MockTransmissionClient.Scenario.forced == nil else { return }
        #endif

        let snapshot = await fetchSnapshot(using: makeTransmissionClient())
        guard snapshot.errorMessage == nil else { return }
        snapshot.save()

        if Date().timeIntervalSince(lastReload) >= Constants.widgetReloadInterval {
            reloadWidget()
            lastReload = Date()
        }
    }
}
