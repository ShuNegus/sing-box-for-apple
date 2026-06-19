import Foundation

// Parsed representation of the optional `turn` block embedded in a Bublik
// sing-box subscription (variant B). The block is NOT part of the sing-box
// schema — the app reads it and strips it before the core consumes the config.
//
// Shape (see turn-subscription-sample.jsonc):
//   "turn": {
//     "version": 1,
//     "defaults": { "wrap_mode": true, "num_streams": 10, ... },
//     "servers": { "<host>": { "supported": true, "peer_addr": "<ip>:56000", "wrap_key_hex": "..." } }
//   }
public struct TurnSubscription {
    public struct Server {
        public let host: String
        public let supported: Bool
        // peer_addr, wrap_key_hex and any per-server overrides (minus `supported`).
        public let fields: [String: Any]
    }

    public let version: Int
    public let defaults: [String: Any]
    public let servers: [String: Server] // keyed by host (== outbound.server)

    public var supportedHosts: Set<String> {
        Set(servers.values.filter(\.supported).map(\.host))
    }

    public var hasSupported: Bool {
        servers.values.contains(where: \.supported)
    }

    public static func parse(config: [String: Any]) -> TurnSubscription? {
        guard let turn = config["turn"] as? [String: Any] else { return nil }
        let version = turn["version"] as? Int ?? 1
        let defaults = turn["defaults"] as? [String: Any] ?? [:]
        var servers: [String: Server] = [:]
        if let raw = turn["servers"] as? [String: Any] {
            for (host, value) in raw {
                guard let entry = value as? [String: Any] else { continue }
                let supported = entry["supported"] as? Bool ?? false
                var fields = entry
                fields.removeValue(forKey: "supported")
                servers[host] = Server(host: host, supported: supported, fields: fields)
            }
        }
        return TurnSubscription(version: version, defaults: defaults, servers: servers)
    }

    public static func parse(configJSON: String) -> TurnSubscription? {
        guard let data = configJSON.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else {
            return nil
        }
        return parse(config: object)
    }
}

// Helpers over the proxy outbounds of a sing-box config.
public enum TurnOutbounds {
    // Outbound types that carry a `server` host and can be TURN-wrapped (TCP).
    public static let proxyTypes: Set<String> = ["vless", "vmess", "trojan", "shadowsocks"]

    // tag -> server host, for proxy outbounds only.
    public static func tagToHost(config: [String: Any]) -> [String: String] {
        guard let outbounds = config["outbounds"] as? [[String: Any]] else { return [:] }
        var map: [String: String] = [:]
        for outbound in outbounds {
            guard let tag = outbound["tag"] as? String,
                  let server = outbound["server"] as? String,
                  let type = outbound["type"] as? String, proxyTypes.contains(type)
            else {
                continue
            }
            map[tag] = server
        }
        return map
    }
}
