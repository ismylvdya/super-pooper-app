import Foundation
import Testing
@testable import SuperPooperApp

/// What the app works out again, and when: the settings once their changes stop, the day plan once per change of its
/// data and minute.
@MainActor
struct DerivedWorkTests {
    private func makeModel() throws -> AppModel {
        try #require(PreviewModel.make()).model
    }

    /// A slider sends a change per step: the screens see each at once, the file is written once the steps stop, and a
    /// change that only alters how things look plans no notifications again.
    @Test func sliderStepsAreWrittenOnceTheyStop() async throws {
        let delay = GatedDelay()
        let recorder = RecordingNotifications()
        let model = try #require(PreviewModel.make(notifications: recorder, delay: delay)).model
        let start = model.settings.timeline.taskFontSize
        for step in 1...5 { model.updateSettings { $0.timeline.taskFontSize = start + Double(step) } }
        #expect(model.settings.timeline.taskFontSize == start + 5)
        #expect(model.parts.services.settingsStore.load().timeline.taskFontSize == start)
        await delay.gate.open()
        await model.parts.settings.waitForSave()
        await model.waitForNotifications()
        #expect(model.parts.services.settingsStore.load().timeline.taskFontSize == start + 5)
        #expect(await recorder.calls == 0)
    }

    /// A new day boundary moves the day: the notifications are planned again, once for all the steps.
    @Test func aNewDayBoundaryPlansTheNotificationsOnce() async throws {
        let delay = GatedDelay()
        let recorder = RecordingNotifications()
        let model = try #require(PreviewModel.make(notifications: recorder, delay: delay)).model
        model.updateSettings { $0.day.boundary = LocalTime("03:00") }
        model.updateSettings { $0.day.boundary = LocalTime("02:00") }
        await delay.gate.open()
        await model.parts.settings.waitForSave()
        await model.waitForNotifications()
        #expect(model.parts.services.settingsStore.load().day.boundary == LocalTime("02:00"))
        #expect(await recorder.calls == 1)
    }

    /// A picture setting is drawn from the settings file: the replan it asks for writes the change first.
    @Test func aPictureSettingIsWrittenBeforeTheReplan() async throws {
        let model = try #require(PreviewModel.make(delay: GatedDelay())).model
        let shown = model.settings.habits.showsNotificationPicture
        await model.setNotificationPictureShown(!shown)
        #expect(model.parts.services.settingsStore.load().habits.showsNotificationPicture == !shown)
    }

    /// The day plan is worked out once per minute and change of its data: asked again within the minute it is the same
    /// plan (a screen asks several times per drawing); new data or the next minute work it out again.
    @Test func thePlanIsWorkedOutOncePerMinuteAndData() async throws {
        let model = try makeModel()
        let minute = PlanKey.minute(of: model.clock.now)
        let first = model.plan(at: minute.addingTimeInterval(5))
        #expect(model.plan(at: minute.addingTimeInterval(50)).now == first.now)
        #expect(first.item(named: "Выпить воды 💧") != nil)
        await model.perform(.skipToday, on: "Выпить воды 💧")
        let changed = model.plan(at: minute.addingTimeInterval(50))
        #expect(changed.now == minute.addingTimeInterval(50))
        #expect(changed.item(named: "Выпить воды 💧") == nil)
        #expect(model.plan(at: minute.addingTimeInterval(65)).now == minute.addingTimeInterval(65))
    }
}
