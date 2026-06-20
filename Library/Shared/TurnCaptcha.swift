import Foundation
import Network

// The vk-turn manual captcha solver hosts a local HTTP server on a fixed port
// inside the tunnel process. The app reaches it over loopback to show a webview.
public enum TurnCaptcha {
    public static let host = "127.0.0.1"
    public static let port: UInt16 = 8765
    public static var url: URL { URL(string: "http://\(host):\(port)/")! }

    // Pure TCP reachability check (no HTTP request, so no side effects on the
    // captcha proxy). Returns true if the local captcha server is up.
    public static func probe(timeout: TimeInterval = 1.0) async -> Bool {
        await withCheckedContinuation { continuation in
            let connection = NWConnection(
                host: NWEndpoint.Host(host),
                port: NWEndpoint.Port(rawValue: port)!,
                using: .tcp
            )
            let resolver = ProbeResolver(continuation)
            connection.stateUpdateHandler = { state in
                switch state {
                case .ready:
                    resolver.finish(true, connection)
                case .failed, .cancelled:
                    resolver.finish(false, connection)
                default:
                    break
                }
            }
            connection.start(queue: .global())
            DispatchQueue.global().asyncAfter(deadline: .now() + timeout) {
                resolver.finish(false, connection)
            }
        }
    }
}

private final class ProbeResolver: @unchecked Sendable {
    private let lock = NSLock()
    private var done = false
    private let continuation: CheckedContinuation<Bool, Never>

    init(_ continuation: CheckedContinuation<Bool, Never>) {
        self.continuation = continuation
    }

    func finish(_ value: Bool, _ connection: NWConnection) {
        lock.lock()
        defer { lock.unlock() }
        if done { return }
        done = true
        connection.cancel()
        continuation.resume(returning: value)
    }
}
