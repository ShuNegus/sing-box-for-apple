import Foundation

public struct TurnPreferences {
    public var enabled: Bool
    public var vkLink: String
    public var peers: Int
    public var captchaManual: Bool
    public var selectedServer: String

    public init(enabled: Bool, vkLink: String, peers: Int, captchaManual: Bool, selectedServer: String = "") {
        self.enabled = enabled
        self.vkLink = vkLink
        self.peers = peers
        self.captchaManual = captchaManual
        self.selectedServer = selectedServer
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

        if let turn, var outbounds = config["outbounds"] as? [[String: Any]] {
            let tagHost = TurnOutbounds.tagToHost(config: config)
            let nodeHosts = Set(turn.servers.keys) // real Bublik nodes (domains), never 127.0.0.1

            // Pick the active server and pin it as the selector `default`. Without this
            // the core falls back to the first member — the localhost "Cascade"
            // outbound — which gives no internet.
            var chosenHost: String?
            for index in outbounds.indices {
                guard outbounds[index]["type"] as? String == "selector",
                      let members = outbounds[index]["outbounds"] as? [String], !members.isEmpty
                else {
                    continue
                }
                let preferred = preferences.selectedServer
                let chosen: String? = (!preferred.isEmpty && members.contains(preferred))
                    ? preferred
                    : members.first { nodeHosts.contains(tagHost[$0] ?? "") }
                if let chosen {
                    outbounds[index]["default"] = chosen
                    if chosenHost == nil { chosenHost = tagHost[chosen] }
                }
            }

            // Inject a `vk-turn` outbound + detour for each supported server.
            let vkLink = preferences.vkLink.trimmingCharacters(in: .whitespacesAndNewlines)
            if preferences.enabled, !vkLink.isEmpty, turn.hasSupported {
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
                    for (key, value) in turn.defaults { options[key] = value }
                    for (key, value) in server.fields { options[key] = value }
                    options["vk_link"] = vkLink
                    options["num_streams"] = preferences.peers
                    // Share one VK credential across all streams → a single
                    // captcha per connect (cred count = num_streams/streams_per_cred).
                    options["streams_per_cred"] = preferences.peers
                    options["manual_captcha"] = preferences.captchaManual
                    injected.append(options)
                    outbounds[index]["detour"] = turnTag
                }
                outbounds.append(contentsOf: injected)
            }

            config["outbounds"] = outbounds

            // Pin the cache namespace to the chosen server so `default` is authoritative
            // (in 1.14 the cached selection otherwise wins over `default`, making the
            // selection "jump back" on connect).
            if let chosenHost,
               var experimental = config["experimental"] as? [String: Any],
               var cacheFile = experimental["cache_file"] as? [String: Any] {
                let base = (cacheFile["cache_id"] as? String) ?? "remnawave"
                let root = base.split(separator: "@").first.map(String.init) ?? base
                cacheFile["cache_id"] = "\(root)@\(chosenHost)"
                experimental["cache_file"] = cacheFile
                config["experimental"] = experimental
            }
        }

        guard let out = try? JSONSerialization.data(withJSONObject: config),
              let string = String(data: out, encoding: .utf8)
        else {
            return configJSON
        }
        return string
    }
}
