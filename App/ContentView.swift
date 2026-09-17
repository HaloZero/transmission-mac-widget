import SwiftUI

struct ContentView: View {
    /// Defaults to whatever `makeTransmissionClient()` decides (real client,
    /// or mock if this is an Xcode Preview / TRANSMISSION_USE_MOCK_DATA is
    /// set). Previews pass an explicit client so each state — normal,
    /// empty, error — can be exercised deliberately rather than left to
    /// auto-detection.
    var client: (any TransmissionFetching)? = nil

    @State private var snapshot = WidgetSnapshot.load()
    @State private var isRefreshing = false

    @Environment(\.openSettings) private var openSettings

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Transmission").font(.headline)
                Spacer()
                Button {
                    Task { await refresh() }
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .buttonStyle(.plain)
                .disabled(isRefreshing)
            }

            if let error = snapshot.errorMessage {
                Text(error).font(.caption).foregroundStyle(.red)
            }

            if snapshot.rows.isEmpty {
                Text("No active torrents").font(.caption).foregroundStyle(.secondary)
            } else {
                ForEach(snapshot.rows.prefix(4)) { row in
                    TorrentRowView(row: row)
                }
            }

            Divider()

            Text("Last updated \(snapshot.fetchedAt, style: .relative) ago")
                .font(.caption2)
                .foregroundStyle(.secondary)

            SettingsLink {
                Text("Preferences…")
            }
            .buttonStyle(.plain)

            #if DEBUG
            Divider()
            Menu("Debug: Load Scenario") {
                Button("Normal") { loadDebugScenario(.normal) }
                Button("Empty") { loadDebugScenario(.empty) }
                Button("Error") { loadDebugScenario(.failure) }
                Divider()
                Button("Resume Live Data") { resumeLiveData() }
                    .disabled(!DebugScenarioLock.isLocked)
            }
            .menuStyle(.borderlessButton)
            #endif
        }
        .padding(12)
        .task { await refresh() }
        .onReceive(NotificationCenter.default.publisher(for: .openSettingsRequested)) { _ in
            openSettings()
        }
    }

    #if DEBUG
    /// Seeds the App Group with a fixed scenario and forces a widget reload,
    /// so WidgetKit Simulator's Snapshot/Timeline controls exercise the same
    /// states as the `MockTransmissionClient` previews without needing a
    /// real (or mock) network round trip. Debug-only: never compiled into
    /// the Release build a user would install.
    private func loadDebugScenario(_ scenario: MockTransmissionClient.Scenario) {
        let newSnapshot: WidgetSnapshot
        switch scenario {
        case .normal:
            newSnapshot = WidgetSnapshot(rows: TorrentInfo.fixtures, fetchedAt: Date(), errorMessage: nil)
        case .empty:
            newSnapshot = WidgetSnapshot(rows: [], fetchedAt: Date(), errorMessage: nil)
        case .failure:
            newSnapshot = WidgetSnapshot(rows: [], fetchedAt: Date(), errorMessage: "Mock failure — simulated RPC error")
        }
        DebugScenarioLock.lock()
        newSnapshot.save()
        snapshot = newSnapshot
        reloadWidget()
    }

    private func resumeLiveData() {
        DebugScenarioLock.unlock()
        Task { await refresh() }
    }
    #endif

    private func refresh() async {
        #if DEBUG
        guard !DebugScenarioLock.isLocked else { return }
        #endif
        isRefreshing = true
        defer { isRefreshing = false }

        let client = self.client ?? makeTransmissionClient()

        do {
            let rows = try await client.fetchTopTorrents(limit: 4)
            let newSnapshot = WidgetSnapshot(rows: rows, fetchedAt: Date(), errorMessage: nil)
            newSnapshot.save()
            snapshot = newSnapshot
            reloadWidget()
        } catch {
            snapshot.errorMessage = error.localizedDescription
        }
    }
}

struct TorrentRowView: View {
    let row: TorrentInfo

    var body: some View {
        HStack {
            Image(systemName: row.status.symbolName)
                .foregroundStyle(.secondary)
                .frame(width: 16)
            VStack(alignment: .leading, spacing: 2) {
                Text(row.name).font(.callout).lineLimit(1)
                Text("\(row.progressLabel) · ↓\(TorrentInfo.formattedRate(row.rateDownload)) · ↑\(TorrentInfo.formattedRate(row.rateUpload))")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
    }
}

#Preview("Normal") {
    ContentView(client: MockTransmissionClient(scenario: .normal))
}

#Preview("Empty") {
    ContentView(client: MockTransmissionClient(scenario: .empty))
}

#Preview("Error") {
    ContentView(client: MockTransmissionClient(scenario: .failure))
}
