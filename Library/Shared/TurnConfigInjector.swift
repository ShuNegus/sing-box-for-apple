import Foundation

public struct TurnPreferences {
    public var enabled: Bool
    public var vkLink: String
    public var peers: Int
    public var captchaManual: Bool

    public init(enabled: Bool, vkLink: String, peers: Int, captchaManual: Bool) {
        self.enabled = enabled
        self.vkLink = vkLink
        self.peers = peers
        self.captchaManual = captchaManual
    }
}

// Transforms a Bublik subscription config before the sing-box core consumes it.
//
// The core strictly rejects unknown fields, so the embedded `turn` block is
// ALWAYS stripped. When TURN is enabled and a VK link is set, a `vk-turn`
// outbound is injected per supported server and the matching proxy outbound
// gets a `detour` pointing at it (variant B — native vk-turn outbound).
public enum TurnConfigInjector {
    // Returns the config with the non-schema `turn` block removed (no injection).
    // Use this anywhere the sing-box core validates a stored subscription
    // (LibboxCheckConfig) — the original (with `turn`) is kept on disk for the UI.
    public static func stripped(configJSON: String) -> String {
        transform(configJSON: configJSON, preferences: TurnPreferences(enabled: false, vkLink: "", peers: 0, captchaManual: false))
    }

    public static func transform(configJSON: String, preferences: TurnPreferences) -> String {
        guard let data = configJSON.data(using: .utf8),
              var config = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else {
            // Not a JSON object (e.g. raw/base64 subscription) — leave untouched.
            return configJSON
        }

        let turn = TurnSubscription.parse(config: config)
        // Strip the non-schema block regardless of the toggle.
        config.removeValue(forKey: "turn")

        let vkLink = preferences.vkLink.trimmingCharacters(in: .whitespacesAndNewlines)
        if preferences.enabled, !vkLink.isEmpty,
           let turn, turn.hasSupported,
           var outbounds = config["outbounds"] as? [[String: Any]] {
            let supported = turn.supportedHosts
            var injected: [[String: Any]] = []
            for index in outbounds.indices {
                guard let host = outbounds[index]["server"] as? String,
                      let type = outbounds[index]["type"] as? String,
                      TurnOutbounds.proxyTypes.contains(type),
                      supported.contains(host),
                      let server = turn.servers[host]
                else {
                    continue
                }
                let turnTag = "vk-turn-\(host)"
                var options: [String: Any] = ["type": "vk-turn", "tag": turnTag]
                // defaults ⊕ per-server fields (peer_addr, wrap_key_hex, overrides)
                for (key, value) in turn.defaults { options[key] = value }
                for (key, value) in server.fields { options[key] = value }
                // user-controlled overrides
                options["vk_link"] = vkLink
                options["num_streams"] = preferences.peers
                options["manual_captcha"] = preferences.captchaManual
                injected.append(options)
                outbounds[index]["detour"] = turnTag
            }
            outbounds.append(contentsOf: injected)
            config["outbounds"] = outbounds
        }

        guard let out = try? JSONSerialization.data(withJSONObject: config),
              let string = String(data: out, encoding: .utf8)
        else {
            return configJSON
        }
        return string
    }
}
