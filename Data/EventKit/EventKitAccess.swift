import EventKit
import UIKit

/// Permission state of a system source, as the app shows it.
enum SourceAccess: Sendable {
    case granted
    case notDetermined
    case denied
}

/// One shared `EKEventStore` for calendars and reminders. Reads and edits run on a queue of their own, off the main
/// thread: a calendar with many events takes a while to read.
final class EventKitAccess: @unchecked Sendable {
    let store = EKEventStore()
    private let queue = DispatchQueue(label: "SuperPooperApp.EventKit", qos: .userInitiated)

    func read<T: Sendable>(_ work: @escaping @Sendable (EKEventStore) -> T) async -> T {
        await withCheckedContinuation { continuation in
            queue.async { continuation.resume(returning: work(self.store)) }
        }
    }

    func write<T: Sendable>(_ work: @escaping @Sendable (EKEventStore) throws -> T) async throws -> T {
        try await withCheckedThrowingContinuation { continuation in
            queue.async { continuation.resume(with: Result { try work(self.store) }) }
        }
    }

    func access(for type: EKEntityType) -> SourceAccess {
        switch EKEventStore.authorizationStatus(for: type) {
        case .fullAccess: .granted
        case .notDetermined: .notDetermined
        default: .denied
        }
    }

    /// Every change of the store (an edit here or elsewhere, a sync with iCloud); one edit can bring several.
    func changes() -> AsyncStream<Void> {
        let store = self.store
        return AsyncStream { continuation in
            let observer = NotificationCenter.default.addObserver(forName: .EKEventStoreChanged, object: store, queue: nil) { _ in
                continuation.yield()
            }
            continuation.onTermination = { _ in NotificationCenter.default.removeObserver(observer) }
        }
    }

    func requestAccess(for type: EKEntityType) async -> Bool {
        do {
            switch type {
            case .event: return try await store.requestFullAccessToEvents()
            case .reminder: return try await store.requestFullAccessToReminders()
            @unknown default: return false
            }
        } catch {
            return false
        }
    }
}

extension EKCalendar {
    var sourceCollection: SourceCollection {
        SourceCollection(id: calendarIdentifier, title: title,
                         colorHex: UIColor(cgColor: cgColor).hexString, sourceTitle: source?.title ?? "")
    }
}
