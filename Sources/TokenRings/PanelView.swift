import AppKit
import Foundation
import SwiftUI
import TokenRingsCore

struct PanelView: View {
    @EnvironmentObject private var store: UsageStore

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider().padding(.vertical, 10)
            VStack(spacing: 14) {
                ForEach(store.readings) { reading in
                    ProviderRow(reading: reading, share: store.share(of: reading.provider))
                }
            }
            Divider().padding(.vertical, 10)
            footer
        }
        .padding(14)
        .frame(width: 340)
        .onAppear { store.refreshIfStale() }
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Token usage")
                    .font(.system(size: 13, weight: .semibold))
                Text("\(Formatting.compact(store.totalToday)) today")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
            Spacer()
            Button {
                store.refresh(forceMuse: true)
            } label: {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 12, weight: .medium))
            }
            .buttonStyle(.borderless)
            .disabled(store.isRefreshing)
            .help("Refresh")
        }
    }

    private var footer: some View {
        HStack {
            Text(statusText)
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
            Spacer()
            Button("Quit") {
                NSApp.terminate(nil)
            }
            .buttonStyle(.borderless)
            .font(.system(size: 10))
        }
    }

    private var statusText: String {
        if store.isRefreshing { return "Refreshing…" }
        guard let date = store.lastRefresh else { return "Loading…" }
        return "Updated \(date.formatted(date: .omitted, time: .shortened))"
    }
}

private struct ProviderRow: View {
    let reading: ProviderReading
    let share: Double

    var body: some View {
        Button {
            NSWorkspace.shared.open(reading.provider.dashboardURL)
        } label: {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 9) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(reading.provider.swiftUIColor)
                        .frame(width: 10, height: 10)
                    Text(reading.provider.title)
                        .font(.system(size: 12, weight: .semibold))
                    Image(systemName: "arrow.up.right")
                        .font(.system(size: 8, weight: .semibold))
                        .foregroundStyle(.tertiary)
                    Spacer()
                    Text(tokensText)
                        .font(.system(size: 12, weight: .semibold))
                        .monospacedDigit()
                }
                .help("Open \(reading.provider.title) usage dashboard")

                if let window = reading.window {
                    LimitRow(label: "5h", limit: window, tint: reading.provider.swiftUIColor)
                }
                if let weekly = reading.weekly {
                    LimitRow(label: "Week", limit: weekly, tint: reading.provider.swiftUIColor)
                }
                if reading.window == nil && reading.weekly == nil {
                    Text("No window limits")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                }
                if let detail {
                    Text(detail)
                        .font(.system(size: 9))
                        .foregroundStyle(reading.error == nil ? Color.secondary : Color.red)
                        .lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityHint("Open \(reading.provider.title) usage dashboard")
    }

    private var tokensText: String {
        reading.tokensToday.map { Formatting.compact($0) } ?? "—"
    }

    private var detail: String? {
        if let error = reading.error { return error }

        var parts: [String] = []
        if let note = reading.note {
            parts.append(note)
        } else if share > 0 {
            parts.append("\(Int((share * 100).rounded()))% of today")
        }
        if let asOf = reading.limitsAsOf, Date().timeIntervalSince(asOf) > 600 {
            parts.append("limits as of \(Formatting.asOf(asOf))")
        }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }
}

private struct LimitRow: View {
    let label: String
    let limit: LimitUsage
    let tint: Color

    var body: some View {
        let remaining = remainingPercent
        HStack(spacing: 7) {
            Text(label)
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(.secondary)
                .frame(width: 30, alignment: .leading)

            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.secondary.opacity(0.22))
                    .frame(width: 42, height: 4)
                Capsule()
                    .fill(barColor(remaining))
                    .frame(width: 42 * remaining / 100, height: 4)
            }
            .frame(width: 42, height: 4)

            Text("\(Int(remaining.rounded()))% left")
                .font(.system(size: 10, weight: .medium))
                .monospacedDigit()
                .frame(width: 54, alignment: .leading)

            Spacer(minLength: 4)

            Text(resetText)
                .font(.system(size: 9))
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .help(tooltip)
    }

    private var remainingPercent: Double {
        let used: Double
        if let resetsAt = limit.resetsAt, resetsAt <= Date() {
            used = 0 // the window reset since this reading
        } else {
            used = limit.percent
        }
        return min(100, max(0, 100 - used))
    }

    private var resetText: String {
        guard let resetsAt = limit.resetsAt else { return "not started" }
        if resetsAt <= Date() { return "window reset" }
        return "resets \(Formatting.reset(resetsAt))"
    }

    private var tooltip: String {
        var parts = ["\(label): \(Int(limit.percent.rounded()))% used"]
        if let resetsAt = limit.resetsAt {
            parts.append("resets \(resetsAt.formatted(date: .abbreviated, time: .shortened))")
        }
        return parts.joined(separator: " · ")
    }

    private func barColor(_ remaining: Double) -> Color {
        if remaining <= 10 { return .red }
        if remaining <= 25 { return .orange }
        return tint
    }
}

private enum Formatting {
    static func compact(_ value: Int64) -> String {
        switch value {
        case ..<1_000:
            return "\(value)"
        case ..<1_000_000:
            return decimal(Double(value) / 1_000, suffix: "K")
        case ..<1_000_000_000:
            return decimal(Double(value) / 1_000_000, suffix: "M")
        default:
            return decimal(Double(value) / 1_000_000_000, suffix: "B")
        }
    }

    static func reset(_ date: Date, now: Date = Date()) -> String {
        let interval = date.timeIntervalSince(now)
        if interval < 86_400 {
            let totalMinutes = max(1, Int(interval / 60))
            let hours = totalMinutes / 60
            let minutes = totalMinutes % 60
            return hours > 0 ? "in \(hours)h \(minutes)m" : "in \(minutes)m"
        }
        if interval < 7 * 86_400 {
            return date.formatted(.dateTime.weekday(.abbreviated).hour().minute())
        }
        return date.formatted(.dateTime.month(.abbreviated).day().hour().minute())
    }

    static func asOf(_ date: Date, now: Date = Date()) -> String {
        if Calendar.current.isDate(date, inSameDayAs: now) {
            return date.formatted(date: .omitted, time: .shortened)
        }
        return date.formatted(.dateTime.month(.abbreviated).day().hour().minute())
    }

    private static func decimal(_ value: Double, suffix: String) -> String {
        let rounded = value.rounded()
        if abs(value - rounded) < 0.05 {
            return "\(Int(rounded))\(suffix)"
        }
        return String(format: "%.1f%@", value, suffix)
    }
}

private extension Provider {
    var swiftUIColor: Color {
        let color = colorComponents
        return Color(red: color.red, green: color.green, blue: color.blue)
    }
}
