import SwiftUI
import AppKit

/// The host app does nothing functional anymore — the widget extension
/// fetches, caches, and is configured entirely on its own (long-press the
/// widget → Edit Widget). This is just a menu bar presence with a way to
/// quit it; quitting only removes the icon; the widget itself keeps working,
/// since WidgetKit manages its process independent of this one.
struct ContentView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Transmission").font(.headline)
            Text("Configure the server from the widget itself: long-press it, then choose Edit Widget.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Divider()

            Button("Quit") {
                NSApplication.shared.terminate(nil)
            }
            .buttonStyle(.plain)
        }
        .padding(12)
        .frame(width: 260)
    }
}

#Preview {
    ContentView()
}
