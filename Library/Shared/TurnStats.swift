import Foundation

// Live per-server TURN pipeline stats, served by the tunnel process over
// loopback (127.0.0.1:8766/stats) — see protocol/vkturn/stats.go.
public struct TurnStat: Codable, Identifiable, Equatable {
    public let tag: String
    public let peerAddr: String
    public let target: Int
    public let active: Int
    public let opened: UInt64
    public let started: Bool

    public var id: String { tag }

    enum CodingKeys: String, CodingKey {
        case tag
        case peerAddr = "peer_addr"
        case target, active, opened, started
    }
}

public enum TurnStats {
    static let endpoint = URL(string: "http://127.0.0.1:8766/stats")!

    public static func fetchAll() async -> [TurnStat] {
        var request = URLRequest(url: endpoint)
        request.timeoutInterval = 2
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 2
        config.waitsForConnectivity = false
        let session = URLSession(configuration: config)
        defer { session.finishTasksAndInvalidate() }
        guard let (data, _) = try? await session.data(for: request),
              let stats = try? JSONDecoder().decode([TurnStat].self, from: data)
        else {
            return []
        }
        return stats
    }
}
