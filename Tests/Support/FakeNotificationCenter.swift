import Foundation
@preconcurrency import UserNotifications
@testable import SuperPooperApp

/// The system notification center in memory: requests wait in `pending` until the test delivers them, as iOS would at
/// their time; an identifier added again replaces the pending request, as in iOS.
final class FakeNotificationCenter: NotificationCenterClient, @unchecked Sendable {
    private let lock = NSLock()
    private var pendingStore: [UNNotificationRequest] = []
    private var deliveredStore: [UNNotificationRequest] = []

    var pending: [UNNotificationRequest] { lock.withLock { pendingStore } }
    var delivered: [UNNotificationRequest] { lock.withLock { deliveredStore } }

    func pending(_ identifier: String) -> UNNotificationRequest? { pending.first { $0.identifier == identifier } }

    /// The pending request fires: it moves to Notification Center (replacing a shown one of the same identifier).
    func deliver(_ identifier: String) {
        lock.withLock {
            guard let index = pendingStore.firstIndex(where: { $0.identifier == identifier }) else { return }
            let request = pendingStore.remove(at: index)
            deliveredStore.removeAll { $0.identifier == identifier }
            deliveredStore.append(request)
        }
    }

    /// The user swipes the notification away.
    func dismiss(_ identifier: String) -> UNNotificationRequest? {
        lock.withLock {
            guard let index = deliveredStore.firstIndex(where: { $0.identifier == identifier }) else { return nil }
            return deliveredStore.remove(at: index)
        }
    }

    func authorizationStatus() async -> UNAuthorizationStatus { .authorized }
    func requestAuthorization(options: UNAuthorizationOptions) async throws -> Bool { true }
    func setNotificationCategories(_ categories: Set<UNNotificationCategory>) {}
    func pendingRequests() async -> [UNNotificationRequest] { pending }
    func deliveredRequests() async -> [UNNotificationRequest] { delivered }

    func add(_ request: UNNotificationRequest) async throws {
        lock.withLock {
            if request.trigger == nil {
                deliveredStore.removeAll { $0.identifier == request.identifier }
                deliveredStore.append(request)
            } else {
                pendingStore.removeAll { $0.identifier == request.identifier }
                pendingStore.append(request)
            }
        }
    }

    func removePendingRequests(withIdentifiers identifiers: [String]) {
        lock.withLock { pendingStore.removeAll { identifiers.contains($0.identifier) } }
    }

    func removeDeliveredNotifications(withIdentifiers identifiers: [String]) {
        lock.withLock { deliveredStore.removeAll { identifiers.contains($0.identifier) } }
    }
}
