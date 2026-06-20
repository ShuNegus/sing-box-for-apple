import Library
import SwiftUI

// Home-card controls shown when the active subscription carries a `turn` block:
// a TURN on/off switch and a server picker. When TURN is on the picker hides
// servers that do not support TURN.
@MainActor
struct TurnProfileControls: View {
    @EnvironmentObject private var environments: ExtensionEnvironments
    @StateObject private var groupModel = GroupListViewModel()

    let profile: ProfilePreview

    @State private var hasTURN = false
    @State private var supportedHosts: Set<String> = []
    @State private var tagToHost: [String: String] = [:]
    @State private var configMembers: [String] = []
    @State private var turnEnabled = false
    @State private var offlineSelection = ""
    @State private var appliedOfflineSelection = false

    var body: some View {
        // NB: an always-present hosting view is required so `.task` actually runs
        // (a Group that resolves to nothing when hasTURN==false would skip it,
        // and load() would never set hasTURN).
        VStack(alignment: .leading, spacing: 12) {
            if hasTURN {
                Divider()
                Toggle(isOn: Binding(get: { turnEnabled }, set: setTurnEnabled)) {
                    Label("Connect through TURN", systemImage: "phone.connection.fill")
                }
                serverPicker
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .task(id: profile.id) {
            await load()
        }
        .onReceive(environments.commandClient.$groups) { groups in
            Task { @MainActor in
                groupModel.setGroups(groups)
                applyOfflineSelectionIfNeeded()
            }
        }
    }

    @ViewBuilder
    private var serverPicker: some View {
        if let group = mainGroup, !visibleItems(group).isEmpty {
            Picker("Server", selection: Binding(
                get: { group.selected },
                set: { selectLive(group, $0) }
            )) {
                ForEach(visibleItems(group), id: \.tag) { item in
                    Text(item.tag).tag(item.tag)
                }
            }
        } else if !visibleOfflineMembers.isEmpty {
            Picker("Server", selection: Binding(get: { offlineSelection }, set: setOfflineSelection)) {
                ForEach(visibleOfflineMembers, id: \.self) { tag in
                    Text(tag).tag(tag)
                }
            }
        }
    }

    // MARK: - Derived

    private var mainGroup: OutboundGroup? {
        groupModel.groups.first { $0.selectable && !$0.items.isEmpty }
    }

    private func tagSupported(_ tag: String) -> Bool {
        guard turnEnabled else { return true }
        guard let host = tagToHost[tag] else { return false }
        return supportedHosts.contains(host)
    }

    private func visibleItems(_ group: OutboundGroup) -> [OutboundGroupItem] {
        group.items.filter { tagSupported($0.tag) }
    }

    private var visibleOfflineMembers: [String] {
        configMembers.filter(tagSupported)
    }

    // MARK: - Actions

    private func setTurnEnabled(_ value: Bool) {
        turnEnabled = value
        Task {
            await SharedPreferences.turnEnabled.set(value)
            if value {
                ensureSupportedSelected()
                #if !os(tvOS)
                    await TurnNotifications.requestAuthorizationIfNeeded()
                #endif
            }
            await restartIfConnected()
        }
    }

    private func selectLive(_ group: OutboundGroup, _ tag: String) {
        offlineSelection = tag
        groupModel.selectOutbound(groupTag: group.tag, outboundTag: tag)
        Task {
            await SharedPreferences.turnSelectedServer.set(tag)
        }
    }

    private func setOfflineSelection(_ tag: String) {
        offlineSelection = tag
        Task {
            await SharedPreferences.turnSelectedServer.set(tag)
        }
    }

    // When TURN is switched on and the current server is unsupported, move the
    // live selection to the first supported one.
    private func ensureSupportedSelected() {
        guard let group = mainGroup else { return }
        let host = tagToHost[group.selected]
        if host == nil || !supportedHosts.contains(host!) {
            if let first = visibleItems(group).first {
                selectLive(group, first.tag)
            }
        }
    }

    // Apply an offline-picked server once the live groups arrive after connecting.
    private func applyOfflineSelectionIfNeeded() {
        guard !appliedOfflineSelection, !offlineSelection.isEmpty,
              let group = mainGroup,
              group.items.contains(where: { $0.tag == offlineSelection }),
              group.selected != offlineSelection
        else {
            return
        }
        appliedOfflineSelection = true
        groupModel.selectOutbound(groupTag: group.tag, outboundTag: offlineSelection)
    }

    private func restartIfConnected() async {
        guard let ext = environments.extensionProfile, ext.status.isConnected else { return }
        try? await ext.stop()
        try? await Task.sleep(nanoseconds: 600_000_000)
        try? await ext.start()
    }

    // MARK: - Load

    private func load() async {
        turnEnabled = await SharedPreferences.turnEnabled.get()
        offlineSelection = await SharedPreferences.turnSelectedServer.get()
        let content = (try? await profile.origin.readAsync()) ?? ""
        if let data = content.data(using: .utf8),
           let config = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            if let turn = TurnSubscription.parse(config: config) {
                hasTURN = turn.hasSupported
                supportedHosts = turn.supportedHosts
            } else {
                hasTURN = false
                supportedHosts = []
            }
            tagToHost = TurnOutbounds.tagToHost(config: config)
            configMembers = TurnOutbounds.selectorGroup(config: config)?.members ?? []
            if offlineSelection.isEmpty {
                offlineSelection = configMembers.first ?? ""
            }
        } else {
            hasTURN = false
        }
        groupModel.connect()
        #if !os(tvOS)
            if hasTURN {
                await TurnNotifications.requestAuthorizationIfNeeded()
            }
        #endif
    }
}
