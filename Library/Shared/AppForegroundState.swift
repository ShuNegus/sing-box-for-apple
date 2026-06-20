import Foundation

// Shared (app-group) flag telling the tunnel-process whether the app is
// currently in the foreground. Used to decide whether a captcha needs a local
// push notification (only when the user is NOT looking at the app).
public enum AppForegroundState {
    private static let key = "app_foreground"

    private static var defaults: UserDefaults? {
        UserDefaults(suiteName: AppConfiguration.appGroupID)
    }

    public static func set(_ foreground: Bool) {
        defaults?.set(foreground, forKey: key)
    }

    // Defaults to true when unset, so a platform that never writes the flag
    // (e.g. macOS) does not get spurious captcha push notifications.
    public static var isForeground: Bool {
        guard let defaults, defaults.object(forKey: key) != nil else {
            return true
        }
        return defaults.bool(forKey: key)
    }
}
