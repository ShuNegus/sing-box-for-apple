import Library
import SwiftUI

public struct TurnSettingView: View {
    @State private var isLoading = true
    @State private var vkLink = ""
    @State private var peers = 10
    @State private var captchaManual = false
    @State private var showCaptcha = false

    public init() {}

    public var body: some View {
        Group {
            if isLoading {
                ProgressView().onAppear {
                    Task {
                        await loadSettings()
                    }
                }
            } else {
                FormView {
                    Section {
                        TextField("https://vk.com/call/join/…", text: $vkLink)
                            #if os(iOS)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled(true)
                                .keyboardType(.URL)
                            #endif
                            .onChangeCompat(of: vkLink) { newValue in
                                Task {
                                    await SharedPreferences.turnVKLink.set(newValue)
                                }
                            }
                    } header: {
                        Text("VK Call Link")
                    } footer: {
                        Text("Ephemeral VK Calls link. Required to connect through TURN — it is entered here, not stored in the subscription.")
                    }

                    Section {
                        Picker("Peers", selection: $peers) {
                            ForEach(1 ... 50, id: \.self) { value in
                                Text("\(value)").tag(value)
                            }
                        }
                        .onChangeCompat(of: peers) { newValue in
                            Task {
                                await SharedPreferences.turnPeers.set(newValue)
                            }
                        }
                    } footer: {
                        Text("Number of parallel TURN sessions (streams). Default 10, max 50.")
                    }

                    Section {
                        Picker("Captcha", selection: $captchaManual) {
                            Text("Automatic").tag(false)
                            Text("Manual").tag(true)
                        }
                        .onChangeCompat(of: captchaManual) { newValue in
                            Task {
                                await SharedPreferences.turnCaptchaManual.set(newValue)
                            }
                        }
                    } footer: {
                        Text("How the VK captcha is solved. Automatic solves it in the background. Manual opens a webview to solve it by hand.")
                    }

                    #if !os(tvOS)
                        if captchaManual {
                            Section {
                                FormButton {
                                    showCaptcha = true
                                } label: {
                                    Label("Solve Captcha", systemImage: "checkmark.shield")
                                }
                            } footer: {
                                Text("Opens the captcha webview manually if it didn't appear automatically while connecting.")
                            }
                        }
                    #endif
                }
            }
        }
        #if !os(tvOS)
        .sheet(isPresented: $showCaptcha) {
            TurnCaptchaSheet()
        }
        #endif
        .navigationTitle("Turn")
        #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
        #endif
    }

    @MainActor
    private func loadSettings() async {
        vkLink = await SharedPreferences.turnVKLink.get()
        peers = await SharedPreferences.turnPeers.get()
        captchaManual = await SharedPreferences.turnCaptchaManual.get()
        isLoading = false
    }
}
