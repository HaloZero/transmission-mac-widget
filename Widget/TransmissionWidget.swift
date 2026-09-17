import WidgetKit
import SwiftUI
import AppIntents
#if canImport(AppKit)
import AppKit
#endif

struct TorrentEntry: TimelineEntry {
    let date: Date
    let rows: [TorrentInfo]
    let errorMessage: String?
}

struct TorrentProvider: TimelineProvider {
    func placeholder(in context: Context) -> TorrentEntry {
        TorrentEntry(date: Date(), rows: [], errorMessage: nil)
    }

    func getSnapshot(in context: Context, completion: @escaping (TorrentEntry) -> Void) {
        // Widget gallery / quick preview — use whatever the app last cached,
        // no network call, so the gallery renders instantly.
        let cached = WidgetSnapshot.load()
        completion(TorrentEntry(date: Date(), rows: Array(cached.rows.prefix(4)), errorMessage: cached.errorMessage))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<TorrentEntry>) -> Void) {
        #if DEBUG
        if DebugScenarioLock.isLocked {
            // A debug scenario is frozen — serve it as-is instead of racing
            // it with a real fetch that would immediately overwrite it.
            let cached = WidgetSnapshot.load()
            let entry = TorrentEntry(date: Date(), rows: cached.rows, errorMessage: cached.errorMessage)
            completion(Timeline(entries: [entry], policy: .never))
            return
        }
        #endif
        Task {
            let client = makeTransmissionClient()

            var entry: TorrentEntry
            do {
                let rows = try await client.fetchTopTorrents(limit: 4)
                WidgetSnapshot(rows: rows, fetchedAt: Date(), errorMessage: nil).save()
                entry = TorrentEntry(date: Date(), rows: rows, errorMessage: nil)
            } catch {
                // Fall back to the last good snapshot rather than showing a
                // blank widget the moment the Mac mini is asleep or offline.
                let cached = WidgetSnapshot.load()
                entry = TorrentEntry(date: Date(), rows: cached.rows, errorMessage: error.localizedDescription)
            }

            // Refresh every 5 minutes — frequent enough to feel live without
            // burning the widget's limited refresh budget. Adjust to taste.
            let nextRefresh = Calendar.current.date(byAdding: .minute, value: 5, to: Date()) ?? Date().addingTimeInterval(300)
            completion(Timeline(entries: [entry], policy: .after(nextRefresh)))
        }
    }
}

struct TransmissionWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: TorrentEntry

    private var maxRows: Int {
        switch family {
        case .systemSmall: return 1
        case .systemMedium: return 2
        default: return 3
        }
    }

    var body: some View {
        Group {
            if let errorMessage = entry.errorMessage, entry.rows.isEmpty {
                WidgetEmptyStateView(family: family, systemImage: "exclamationmark.triangle", message: errorMessage, isError: true)
            } else if entry.rows.isEmpty {
                WidgetEmptyStateView(family: family, systemImage: "tray", message: "No active torrents", isError: false)
            } else {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(entry.rows.prefix(maxRows)) { row in
                        WidgetTorrentRow(row: row)
                    }
                    Spacer(minLength: 0)
                }
                .padding(12)
            }
        }
        .containerBackground(.fill.tertiary, for: .widget)
        .overlay(alignment: .topTrailing) {
            Button(intent: OpenSettingsIntent()) {
                Image(systemName: "gearshape.fill")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .padding(8)
            }
            .buttonStyle(.plain)
        }
    }
}

private struct WidgetEmptyStateView: View {
    let family: WidgetFamily
    let systemImage: String
    let message: String
    let isError: Bool

    var body: some View {
        VStack(spacing: family == .systemSmall ? 6 : 10) {
            Image(systemName: systemImage)
                .font(family == .systemLarge ? .largeTitle : .title2)
            Text(message)
                .font(family == .systemLarge ? .title3 : .subheadline)
                .multilineTextAlignment(.center)
        }
        .foregroundStyle(isError ? .red : .secondary)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(20)
    }
}

private struct WidgetTorrentRow: View {
    let row: TorrentInfo

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: row.status.symbolName)
                .font(.body)
                .foregroundStyle(.secondary)
                .frame(width: 16)

            VStack(alignment: .leading, spacing: 6) {
                Text(row.name)
                    .font(.subheadline)
                    .lineLimit(1)
                HStack(spacing: 6) {
                    ProgressView(value: row.percentDone)
                        .progressViewStyle(.linear)
                    Text(row.progressLabel)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
            }

            Spacer(minLength: 8)

            VStack(alignment: .trailing, spacing: 3) {
                Label(TorrentInfo.formattedRate(row.rateDownload), systemImage: "arrow.down")
                Label(TorrentInfo.formattedRate(row.rateUpload), systemImage: "arrow.up")
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
    }
}

struct TransmissionWidget: Widget {
    let kind = "TransmissionWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: TorrentProvider()) { entry in
            TransmissionWidgetView(entry: entry)
        }
        .configurationDisplayName("Transmission")
        .description("Shows your most active torrents.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}

#Preview(as: .systemMedium) {
    TransmissionWidget()
} timeline: {
    TorrentEntry(date: .now, rows: Array(TorrentInfo.fixtures.prefix(4)), errorMessage: nil)
}

#Preview("Empty", as: .systemMedium) {
    TransmissionWidget()
} timeline: {
    TorrentEntry(date: .now, rows: [], errorMessage: nil)
}

#Preview("Error", as: .systemMedium) {
    TransmissionWidget()
} timeline: {
    TorrentEntry(date: .now, rows: [], errorMessage: "Could not reach Transmission")
}
