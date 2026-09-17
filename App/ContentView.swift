import SwiftUI

struct ContentView: View {
    /// Defaults to whatever `TransmissionClientFactory.make()` decides (real client,
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

            if snapshot.downloadedSinceLastRefresh > 0 || snapshot.uploadedSinceLastRefresh > 0 {
                Text("Since last refresh: ↓\(TorrentInfo.formattedBytes(snapshot.downloadedSinceLastRefresh)) · ↑\(TorrentInfo.formattedBytes(snapshot.uploadedSinceLastRefresh))")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            SettingsLink {
                Text("Preferences…")
            }
            .buttonStyle(.plain)

            #if DEBUG
            Divider()
            Menu("Debug: Load Scenario") {
                Button("Normal") { setDebugScenario(.normal) }
                Button("Empty") { setDebugScenario(.empty) }
                Button("Error") { setDebugScenario(.failure) }
                Divider()
                Button("Live Data") { setDebugScenario(nil) }
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
    /// Sets (or clears) the forced scenario and immediately refreshes so the
    /// change is visible right away — see `MockTransmissionClient.Scenario`
    /// for where "forced" is actually resolved and consumed.
    private func setDebugScenario(_ scenario: MockTransmissionClient.Scenario?) {
        MockTransmissionClient.Scenario.forced = scenario
        Task { await refresh() }
    }
    #endif

    private func refresh() async {
        #if DEBUG
        if client == nil, let forced = MockTransmissionClient.Scenario.forced {
            let newSnapshot = await forced.makeSnapshot()
            newSnapshot.save()
            snapshot = newSnapshot
            WidgetReloader.reload()
            return
        }
        #endif
        isRefreshing = true
        defer { isRefreshing = false }

        let client = self.client ?? TransmissionClientFactory.make()
        let newSnapshot = await SnapshotFetcher.fetch(using: client)
        snapshot = newSnapshot
        if newSnapshot.errorMessage == nil {
            newSnapshot.save()
            WidgetReloader.reload()
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
