import Foundation

#if canImport(UIKit)
    import UIKit
#elseif canImport(AppKit)
    import AppKit
#endif

// Cross-platform read of the system clipboard's plain-text contents.
public enum Clipboard {
    public static var string: String? {
        #if canImport(UIKit)
            return UIPasteboard.general.string
        #elseif canImport(AppKit)
            return NSPasteboard.general.string(forType: .string)
        #else
            return nil
        #endif
    }
}
