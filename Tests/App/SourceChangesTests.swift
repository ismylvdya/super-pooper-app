import Foundation
import Testing
@testable import SuperPooperApp

/// Changes of Calendar and Reminders, made elsewhere or by the app, are read once per burst.
@MainActor
struct SourceChangesTests {
    /// A sync of several events posts a notice per event: the sources were read (and the notifications planned) once per
    /// notice, now once for the burst.
    @Test func aBurstOfChangesIsReadOnce() async throws {
        let calendars = ChangingCalendars()
        let delay = GatedDelay()
        let model = try #require(PreviewModel.make(calendars: calendars, delay: delay)).model
        model.observeSourceChanges()
        for _ in 0..<5 { calendars.change() }
        await delay.gate.arrived(5)
        await delay.gate.open()
        await model.waitForSourceRefresh()
        #expect(calendars.reads == 1)
    }

    /// A reminder checked off shows at once; the store's own notice of that edit brings the one read that follows it.
    @Test func anOwnEditShowsAtOnceAndIsReadBackOnce() async throws {
        let calendars = ChangingCalendars()
        let delay = GatedDelay()
        let model = try #require(PreviewModel.make(calendars: calendars, delay: delay)).model
        model.observeSourceChanges()
        let reminder = try #require(model.reminders.first)
        await model.toggleReminder(reminder)
        #expect(model.reminders.first { $0.id == reminder.id }?.isCompleted == true)
        #expect(calendars.reads == 0)
        calendars.change()
        await delay.gate.arrived(2)
        await delay.gate.open()
        await model.waitForSourceRefresh()
        #expect(calendars.reads == 1)
    }
}
