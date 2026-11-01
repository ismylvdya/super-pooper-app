import Foundation
import Testing
@testable import SuperPooperApp

/// Checking off a reminder from the timeline or its notification.
@MainActor
struct ReminderEditTests {
    /// A reminder deleted in Reminders meanwhile: a problem banner, not a check mark that never reached Reminders.
    @Test func aReminderThatIsGoneIsNotShownAsDone() async throws {
        let events = RecordingEvents()
        let model = try #require(PreviewModel.make(reminders: GoneReminders(), delay: NoDelay(), appEvents: events)).model
        let reminder = try #require(model.reminders.first)
        await model.toggleReminder(reminder)
        #expect(events.sent == [.failure(.reminderNotFound)])
        await model.waitForSourceRefresh()
        #expect(model.reminders.isEmpty)
    }

    /// The Complete button of a reminder's notification checks it off once; a second press leaves it done.
    @Test func theNotificationButtonCompletesTheReminder() async throws {
        let model = try #require(PreviewModel.make(delay: GatedDelay())).model
        let reminder = try #require(model.reminders.first)
        await model.completeReminder(id: reminder.id)
        #expect(model.reminders.first?.isCompleted == true)
        await model.completeReminder(id: reminder.id)
        #expect(model.reminders.first?.isCompleted == true)
    }
}
