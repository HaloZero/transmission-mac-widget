import WidgetKit
import SwiftUI
import AppIntents
#if canImport(AppKit)
import AppKit
#endif

struct TransmissionWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: TorrentEntry

    private var maxRows: Int {
        switch family {
        case .systemMedium: return 3
        default: return 6
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
                    .font(.system(size: 8, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.6), radius: 0.5)
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
    TorrentEntry(date: .now, rows: TorrentInfo.fixtures, errorMessage: nil)
}

#Preview(as: .systemLarge) {
    TransmissionWidget()
} timeline: {
    TorrentEntry(date: .now, rows: TorrentInfo.fixtures, errorMessage: nil)
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
