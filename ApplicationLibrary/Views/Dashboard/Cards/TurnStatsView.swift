import Library
import SwiftUI

// Live TURN pipeline stats for the active server, shown under the TURN controls
// while connected. Polls the tunnel-process stats endpoint over loopback.
@MainActor
struct TurnStatsView: View {
    // Host of the currently-selected server (to pick the matching vk-turn outbound).
    let activeHost: String?

    @State private var stat: TurnStat?
    @State private var task: Task<Void, Never>?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Divider()
            HStack {
                Label("TURN", systemImage: "point.3.connected.trianglepath.dotted")
                    .font(.subheadline.weight(.semibold))
                Spacer()
                statusBadge(stat)
            }
            statRow(String(localized: "Peers"), stat.map { "\($0.active)/\($0.target)" } ?? "—")
            statRow(String(localized: "Streams opened"), stat.map { "\($0.opened)" } ?? "—")
        }
        .onAppear { start() }
        .onDisappear { stop() }
    }

    private func statRow(_ name: String, _ value: String) -> some View {
        HStack {
            Text(name)
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.caption.monospacedDigit())
                .foregroundStyle(.primary)
        }
    }

    @ViewBuilder
    private func statusBadge(_ stat: TurnStat?) -> some View {
        let (text, color) = stage(stat)
        Text(text)
            .font(.caption.weight(.medium))
            .foregroundStyle(color)
    }

    private func stage(_ stat: TurnStat?) -> (String, Color) {
        guard let stat, stat.started else {
            return (String(localized: "Connecting…"), .orange)
        }
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
                stat = pick(all)
                try? await Task.sleep(nanoseconds: 2_000_000_000)
            }
        }
    }

    private func stop() {
        task?.cancel()
        task = nil
    }

    // Prefer the outbound for the selected host; else the started one with most
    // active sessions; else any entry (so target shows before the first dial).
    private func pick(_ all: [TurnStat]) -> TurnStat? {
        if let host = activeHost,
           let match = all.first(where: { $0.tag == "vk-turn-\(host)" }) {
            return match
        }
        if let started = all.filter(\.started).max(by: { $0.active < $1.active }) {
            return started
        }
        return all.first
    }
}
