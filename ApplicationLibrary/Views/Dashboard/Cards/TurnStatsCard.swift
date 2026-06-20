import Library
import SwiftUI

// Full-width dashboard card with live TURN pipeline stats. Self-hiding: renders
// nothing unless connected through TURN (the tunnel reports a started vk-turn
// outbound). Shown above the System HTTP Proxy card.
@MainActor
public struct TurnStatsCard: View {
    @State private var stat: TurnStat?
    @State private var task: Task<Void, Never>?

    public init() {}

    public var body: some View {
        Group {
            if let stat, stat.started {
                DashboardCardView(title: "", isHalfWidth: false) {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            DashboardCardHeader(icon: "point.3.connected.trianglepath.dotted", title: "TURN")
                            Spacer()
                            statusBadge(stat)
                        }
                        statRow(String(localized: "Peers"), "\(stat.active)/\(stat.target)")
                        statRow(String(localized: "Streams opened"), "\(stat.opened)")
                    }
                }
            }
        }
        .onAppear { start() }
        .onDisappear { stop() }
    }

    private func statRow(_ name: String, _ value: String) -> some View {
        HStack {
            Text(name)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.subheadline.monospacedDigit())
                .foregroundStyle(.primary)
        }
    }

    @ViewBuilder
    private func statusBadge(_ stat: TurnStat) -> some View {
        let (text, color) = stage(stat)
        Text(text)
            .font(.subheadline.weight(.medium))
            .foregroundStyle(color)
    }

    private func stage(_ stat: TurnStat) -> (String, Color) {
        if stat.active == 0 {
            return (String(localized: "Connecting…"), .orange)
        }
        if stat.active < stat.target {
            return (String(localized: "Establishing"), .orange)
        }
        return (String(localized: "Active"), .green)
    }

    private func start() {
        guard task == nil else { return }
        task = Task {
            while !Task.isCancelled {
                let all = await TurnStats.fetchAll()
                // The in-use server is the one whose lazy dialer has started.
                stat = all.filter(\.started).max(by: { $0.active < $1.active })
                try? await Task.sleep(nanoseconds: 2_000_000_000)
            }
        }
    }

    private func stop() {
        task?.cancel()
        task = nil
    }
}
