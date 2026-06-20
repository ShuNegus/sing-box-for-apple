import Foundation

#if !os(tvOS)
    import UserNotifications

    // Local-notification permission used to alert about a TURN captcha while the
    // app is backgrounded. Requested from foreground UI (settings / dashboard
    // controls) so the system prompt actually appears.
    public enum TurnNotifications {
        public static func requestAuthorizationIfNeeded() async {
            let center = UNUserNotificationCenter.current()
            let settings = await center.notificationSettings()
            switch settings.authorizationStatus {
            case .notDetermined:
                _ = try? await center.requestAuthorization(options: [.alert, .sound])
            default:
                break
            }
        }
    }
#endif
