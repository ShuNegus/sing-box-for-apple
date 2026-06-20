#if !os(tvOS)

import Library
import SwiftUI
import WebKit

// Sheet that hosts the VK captcha page served by the tunnel-process local
// server over loopback. Dismissed automatically when the server goes away
// (captcha solved) — see TurnCaptchaMonitor.
public struct TurnCaptchaSheet: View {
    @Environment(\.dismiss) private var dismiss

    public init() {}

    public var body: some View {
        NavigationStackCompat {
            CaptchaWebView(url: TurnCaptcha.url)
                .ignoresSafeArea(edges: .bottom)
                .navigationTitle("Solve Captcha")
                #if os(iOS)
                .navigationBarTitleDisplayMode(.inline)
                #endif
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Close") { dismiss() }
                    }
                }
        }
    }
}

#if os(macOS)
    private struct CaptchaWebView: NSViewRepresentable {
        let url: URL
        func makeNSView(context _: Context) -> WKWebView { makeWebView(url) }
        func updateNSView(_: WKWebView, context _: Context) {}
    }
#else
    private struct CaptchaWebView: UIViewRepresentable {
        let url: URL
        func makeUIView(context _: Context) -> WKWebView { makeWebView(url) }
        func updateUIView(_: WKWebView, context _: Context) {}
    }
#endif

private func makeWebView(_ url: URL) -> WKWebView {
    let configuration = WKWebViewConfiguration()
    configuration.websiteDataStore = .nonPersistent()
    let webView = WKWebView(frame: .zero, configuration: configuration)
    #if os(iOS)
        webView.scrollView.contentInsetAdjustmentBehavior = .always
    #endif
    webView.load(URLRequest(url: url))
    return webView
}

#endif
