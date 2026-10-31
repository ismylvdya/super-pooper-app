import Foundation
import Testing
@testable import SuperPooperApp

/// The buttons of a delivered notification act on the day the notification belongs to.
@MainActor
struct NotificationActionTests {
    private let water = "Выпить воды 💧"

    private func model(waterReminders times: [LocalTime]) throws -> AppModel {
        let tasks = PreviewSamples.tasks.map { task -> TaskNote in
            guard task.name == water else { return task }
            var habit = task
            habit.reminderTimes = times
            return habit
        }
        return try #require(PreviewModel.make(tasks: tasks)).model
    }

    private func mark(_ model: AppModel, on day: LocalDate) -> HabitMark? {
        model.task(named: water).flatMap { $0.mark(on: day) }
    }

    /// The habit's second reminder of the day pressed Done again: the day is Twice.
    @Test func aSecondDoneOnAHabitWithTwoRemindersIsTwice() async throws {
        let model = try model(waterReminders: [LocalTime("09:00"), LocalTime("21:00")])
        let today = model.context().today
        await model.performNotificationAction(.done, on: water, day: today)
        #expect(mark(model, on: today) == .done)
        await model.performNotificationAction(.done, on: water, day: today)
        #expect(mark(model, on: today) == .twice)
    }

    @Test func aSecondDoneOnAHabitWithOneReminderStaysDone() async throws {
        let model = try model(waterReminders: [LocalTime("09:00")])
        let today = model.context().today
        await model.performNotificationAction(.done, on: water, day: today)
        await model.performNotificationAction(.done, on: water, day: today)
        #expect(mark(model, on: today) == .done)
    }

    /// Yesterday's notification left in Notification Center marks yesterday, not today.
    @Test func aNotificationOfAnEarlierDayMarksThatDay() async throws {
        let model = try model(waterReminders: [LocalTime("09:00")])
        let today = model.context().today
        let earlier = today.adding(days: -3)
        await model.performNotificationAction(.partial, on: water, day: earlier)
        #expect(mark(model, on: earlier) == .partial)
        #expect(mark(model, on: today) == nil)
    }

    @Test func aTaskIsSimplyDone() async throws {
        let model = try model(waterReminders: [])
        await model.performNotificationAction(.done, on: "Забрать посылку", day: model.context().today)
        #expect(model.task(named: "Забрать посылку") == nil)
        await model.loadFiledTasks()
        #expect(model.filedTasks.contains { $0.name == "Забрать посылку" && $0.status == .done })
    }
}
