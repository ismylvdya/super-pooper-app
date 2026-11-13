import UIKit

/// Work that must end even when the app has just left the screen: the system is asked for the time it takes, and told
/// when it is done. Without it the app may be suspended halfway through writing.
@MainActor
enum BackgroundTime {
    private final class Ticket {
        var id: UIBackgroundTaskIdentifier = .invalid

        func end() {
            guard id != .invalid else { return }
            UIApplication.shared.endBackgroundTask(id)
            id = .invalid
        }
    }

    static func finish<Value>(_ name: String, _ work: () async -> Value) async -> Value {
        let ticket = Ticket()
        ticket.id = UIApplication.shared.beginBackgroundTask(withName: name) { ticket.end() }
        let value = await work()
        ticket.end()
        return value
    }
}
