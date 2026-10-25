import EventKit
import UIKit

/// Permission state of a system source, as the app shows it.
enum SourceAccess: Sendable {
    case granted
    case notDetermined
    case denied
}

/// One shared `EKEventStore` for calendars and reminders.
final class EventKitAccess: @unchecked Sendable {
    let store = EKEventStore()

    func access(for type: EKEntityType) -> SourceAccess {
        switch EKEventStore.authorizationStatus(for: type) {
        case .fullAccess: .granted
        case .notDetermined: .notDetermined
        default: .denied
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
