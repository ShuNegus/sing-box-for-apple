import Library
import SwiftUI

// Polls the tunnel-process TURN stats endpoint and publishes the in-use server's
// snapshot. Owned by an always-present view (OverviewView) so polling runs even
// while the card itself is hidden.
@MainActor
public final class TurnStatsModel: ObservableObject {
    // Whether the TURN switch is on (drives card visibility together with the
    // tunnel status). The snapshot only fills in the numbers.
    @Published public private(set) var enabled = false
    @Published public private(set) var current: TurnStat?

    private var task: Task<Void, Never>?

    public init() {}

    public func start() {
        guard task == nil else { return }
        task = Task { [weak self] in
            while !Task.isCancelled {
                let on = await SharedPreferences.turnEnabled.get()
                self?.enabled = on
                if on {
                    let all = await TurnStats.fetchAll()
                    // The in-use server is the one whose lazy dialer has started.
                    self?.current = all.filter(\.started).max(by: { $0.active < $1.active })
                } else {
                    self?.current = nil
                }
                try? await Task.sleep(nanoseconds: 2_000_000_000)
            }
        }
    }

    public func stop() {
        task?.cancel()
        task = nil
        enabled = false
        current = nil
    }
}

// Full-width dashboard card with live TURN pipeline stats. Rendered only when a
// started vk-turn outbound exists (connected through TURN), above System HTTP Proxy.
public struct TurnStatsCard: View {
    let stat: TurnStat?

    public init(stat: TurnStat?) {
        self.stat = stat
    }

    public var body: some View {
        DashboardCardView(title: "", isHalfWidth: false) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    DashboardCardHeader(icon: "point.3.connected.trianglepath.dotted", title: "TURN")
                    Spacer()
                    statusBadge
                }
                statRow(String(localized: "Peers"), stat.map { "\($0.active)/\($0.target)" } ?? "—")
                statRow(String(localized: "Streams opened"), stat.map { "\($0.opened)" } ?? "—")
            }
        }
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
    private var statusBadge: some View {
        let (text, color) = stage
        Text(text)
            .font(.subheadline.weight(.medium))
            .foregroundStyle(color)
    }

    private var stage: (String, Color) {
        guard let stat, stat.active > 0 else {
            return (String(localized: "Connecting…"), .orange)
        }
        if stat.active < stat.target {
            return (String(localized: "Establishing"), .orange)
        }
        return (String(localized: "Active"), .green)
    }
}
