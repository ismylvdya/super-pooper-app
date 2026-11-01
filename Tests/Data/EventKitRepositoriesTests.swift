import Foundation
import Testing
@testable import SuperPooperApp

/// The EventKit repositories on a store without the items asked for (the test host has no Calendar or Reminders data).
struct EventKitRepositoriesTests {
    /// The bug: checking off a reminder deleted elsewhere "succeeded" without a word.
    @Test func completingAReminderThatIsGoneIsAnError() async {
        let repository = EventKitRemindersRepository(eventKit: EventKitAccess(), calendar: FixedCalendar(current: TestCalendar.calendar))
        await #expect(throws: ReminderEditError.reminderNotFound) {
            try await repository.setCompleted(true, reminderID: "gone")
        }
    }

    @Test func deletingAnEventThatIsGoneIsAnError() async {
        let repository = EventKitCalendarRepository(eventKit: EventKitAccess())
        let event = makeEvent("Gone", from: "10:00", to: "11:00")
        await #expect(throws: CalendarEditError.self) {
            try await repository.delete(event)
        }
    }
}
