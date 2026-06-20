import Library
import SwiftUI

// Polls the tunnel-process local captcha server (127.0.0.1:8765) while TURN is
// active in manual-captcha mode, and drives the captcha webview sheet.
@MainActor
public final class TurnCaptchaMonitor: ObservableObject {
    @Published public var showCaptcha = false

    private var task: Task<Void, Never>?
    private var wasReachable = false
    private var suppressed = false

    public init() {}

    // Driven by the app root from the tunnel status.
    public func setActive(_ active: Bool) {
        if active {
            guard task == nil else { return }
            task = Task { [weak self] in
                await self?.loop()
            }
        } else {
            task?.cancel()
            task = nil
            wasReachable = false
            suppressed = false
            showCaptcha = false
        }
    }

    // Called when the sheet is dismissed (user closed it): don't re-open until
    // the server cycles (a new captcha appears).
    public func userDismissed() {
        suppressed = true
        showCaptcha = false
    }

    private func loop() async {
        while !Task.isCancelled {
            let enabled = await SharedPreferences.turnEnabled.get()
            let manual = await SharedPreferences.turnCaptchaManual.get()
            if enabled, manual {
                let reachable = await TurnCaptcha.probe()
                if reachable {
                    if !wasReachable, !suppressed {
                        showCaptcha = true
                    }
                } else {
                    suppressed = false
                    if showCaptcha {
                        showCaptcha = false // server gone => captcha solved/aborted
                    }
                }
                wasReachable = reachable
            } else if showCaptcha {
                showCaptcha = false
            }
            try? await Task.sleep(nanoseconds: 1_500_000_000)
        }
    }
}
