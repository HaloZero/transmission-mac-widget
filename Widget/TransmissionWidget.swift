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
        HStack(alignment: .center, spacing: 10) {
            Image(systemName: row.contentSymbolName)
                .font(.body)
                .foregroundStyle(.secondary)
                .frame(width: 16)

            VStack(alignment: .leading, spacing: 4) {
                Text(row.name)
                    .font(.subheadline)
                    .lineLimit(1)
                Text("\(row.status.statusLabel) · \(row.progressLabel) · ↓\(TorrentInfo.formattedRate(row.rateDownload)) · ↑\(TorrentInfo.formattedRate(row.rateUpload))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            TorrentProgressCircle(percentDone: row.percentDone)
        }
    }
}

/// A filled pie-style progress indicator: the wedge grows clockwise from the
/// top with `percentDone`, blue while in progress and green once complete.
/// The percentage label only appears while incomplete — a full green circle
/// already says "done" without it.
private struct TorrentProgressCircle: View {
    let percentDone: Double

    private var clampedPercent: Double { min(max(percentDone, 0), 1) }
    private var isComplete: Bool { clampedPercent >= 1.0 }

    var body: some View {
        ZStack {
            Circle()
                .fill(Color.secondary.opacity(0.15))

            PieSlice(percent: clampedPercent)
                .fill(isComplete ? Color.green : Color.blue)

            if !isComplete {
                Text(String(format: "%.0f", clampedPercent * 100))
                    .font(.system(size: 8, weight: .semibold))
                    .foregroundStyle(.primary)
            }
        }
        .frame(width: 24, height: 24)
    }
}

private struct PieSlice: Shape {
    var percent: Double

    func path(in rect: CGRect) -> Path {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius = min(rect.width, rect.height) / 2
        let startAngle = Angle(degrees: -90)
        let endAngle = Angle(degrees: -90 + 360 * percent)

        var path = Path()
        path.move(to: center)
        path.addLine(to: CGPoint(x: center.x, y: center.y - radius))
        path.addArc(center: center, radius: radius, startAngle: startAngle, endAngle: endAngle, clockwise: false)
        path.closeSubpath()
        return path
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
        .supportedFamilies([.systemMedium, .systemLarge])
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
