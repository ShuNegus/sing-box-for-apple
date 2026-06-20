import Foundation
import UserNotifications

// Runs inside the tunnel (NE) process. The vk-turn manual-captcha solver hosts a
// local server on 127.0.0.1:8765 while waiting for the user. The in-app monitor
// can't detect that while the app is suspended, so this polls the loopback port
// here and posts a local notification when a captcha appears and the app is not
// in the foreground. Tapping it opens the app, whose monitor then shows the webview.
public final class CaptchaNotifier {
    private var task: Task<Void, Never>?
    private let notificationID = "turn-captcha"

    public init() {}

    public func start() {
        guard task == nil else { return }
        task = Task { [weak self] in
            await self?.loop()
        }
    }

    public func stop() {
        task?.cancel()
        task = nil
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [notificationID])
        UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: [notificationID])
    }

    private func loop() async {
        var wasReachable = false
        while !Task.isCancelled {
            let reachable = await TurnCaptcha.probe()
            if reachable, !wasReachable {
                if !AppForegroundState.isForeground {
                    await postNotification()
                }
            } else if !reachable, wasReachable {
                // Captcha solved/aborted — clear any standing notification.
                UNUserNotificationCenter.current().removeDeliveredNotifications(withIdentifiers: [notificationID])
            }
            wasReachable = reachable
            try? await Task.sleep(nanoseconds: 1_500_000_000)
        }
    }

    private func postNotification() async {
        let content = UNMutableNotificationContent()
        content.title = String(localized: "Captcha required")
        content.body = String(localized: "Open the app to solve the captcha and connect through TURN.")
        content.interruptionLevel = .timeSensitive
        let request = UNNotificationRequest(identifier: notificationID, content: content, trigger: nil)
        let center = UNUserNotificationCenter.current()
        try? await center.add(request)
    }
}
