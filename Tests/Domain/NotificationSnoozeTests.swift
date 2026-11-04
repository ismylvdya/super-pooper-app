import Foundation
import Testing
@testable import SuperPooperApp

/// A snoozed notification comes again, the same, while the notification itself would stay: its item open on its day,
/// and only within that day. Wednesday 2026-10-21 in Belgrade.
struct NotificationSnoozeTests {
    private let planner = NotificationPlanner(horizonDays: TestConfig.rules.notifications.horizonDays,
                                              limit: TestConfig.rules.notifications.limit)
    private let water = makeHabit("Вода", status: .habit) { $0.reminderTimes = [LocalTime("09:00")] }
    private let wednesday = LocalDate(TestCalendar.wednesday)

    private func snoozed(_ tasks: [TaskItem], _ snoozes: [NotificationSnooze], at time: String,
                         on day: String = TestCalendar.wednesday, events: [CalendarEvent] = []) -> [PlannedNotification] {
        let context = TestCalendar.context(day, time)
        let valid = planner.stillValidToday(tasks: tasks, reminders: [], events: events, skipped: [], context: context)
        return NotificationSnoozing.notifications(snoozes, valid: valid, context: context)
    }

    private func snooze(_ key: String, until time: String, on day: String = TestCalendar.wednesday) -> NotificationSnooze {
        NotificationSnooze(key: key, day: wednesday, until: TestCalendar.date(day, time))
    }

    private var waterSlot: String { NotificationPlanner.habitSlot("Вода", LocalTime("09:00")) }

    @Test func aSnoozedHabitNotificationComesAgainTheSameUnderAnIdOfItsOwn() throws {
        let again = try #require(snoozed([water], [snooze(waterSlot, until: "10:05")], at: "09:05").first)
        #expect(again.fireDate == TestCalendar.date(TestCalendar.wednesday, "10:05"))
        #expect((again.kind, again.title, again.taskName, again.day, again.key) == (.habit, "Вода", "Вода", wednesday, waterSlot))
        #expect(again.id != waterSlot, "never the slot's identifier: tomorrow's request keeps its place")
        #expect(again.isAbsolute, "an hour from the press, wherever the phone is")
    }

    /// An event alert comes again with the event's own start, so its text stays as it was.
    @Test func aSnoozedEventAlertKeepsTheEventsStart() throws {
        var standup = makeEvent("Standup", from: "15:15", to: "16:15")
        standup.alarmDates = [TestCalendar.date(TestCalendar.wednesday, "15:00")]
        let key = "event|\(standup.eventIdentifier)|0"
        let again = try #require(snoozed([], [snooze(key, until: "16:00")], at: "15:00", events: [standup]).first)
        #expect(again.start == standup.start)
        #expect(again.eventID == standup.eventIdentifier)
        #expect(again.title == "Standup")
    }

    @Test func itGoesOnceItsItemIsDoneOrGone() {
        let done = water.applying([.mark(.done, on: wednesday)])
        #expect(snoozed([done], [snooze(waterSlot, until: "10:05")], at: "09:30").isEmpty)
        #expect(snoozed([], [snooze(waterSlot, until: "10:05")], at: "09:30").isEmpty)
    }

    /// It lives its logical day: one of a day that is over is not planned, nor one that would come after its day ends.
    @Test func itNeverOutlivesItsDay() {
        #expect(snoozed([water], [snooze(waterSlot, until: "10:05")], at: "08:00", on: "2026-10-22").isEmpty)
        // 03:30 is still Wednesday's night (boundary 04:00); an hour later is Thursday.
        #expect(snoozed([water], [snooze(waterSlot, until: "04:30", on: "2026-10-22")], at: "03:30", on: "2026-10-22").isEmpty)
        #expect(snoozed([water], [snooze(waterSlot, until: "03:50", on: "2026-10-22")], at: "03:30", on: "2026-10-22").count == 1)
    }

    @Test func aNewSnoozeReplacesTheOldOneAndDaysThatAreOverAreForgotten() {
        let old = NotificationSnooze(key: waterSlot, day: wednesday.adding(days: -1), until: TestCalendar.date("2026-10-20", "10:00"))
        let first = snooze(waterSlot, until: "10:05")
        let other = snooze("task|Позвонить", until: "10:10")
        let second = snooze(waterSlot, until: "11:05")
        let snoozes = NotificationSnoozing.adding(second, to: [old, first, other], today: wednesday)
        #expect(snoozes == [other, second])
    }

    // MARK: - A task's or habit's block moves

    private func moves(_ tasks: [TaskItem], key: String, at time: String, until: String, untilDay: String = TestCalendar.wednesday,
                       events: [CalendarEvent] = [], reminders: [ReminderItem] = []) -> [TimeMove]? {
        let context = TestCalendar.context(TestCalendar.wednesday, time)
        let all = planner.all(tasks: tasks, reminders: reminders, events: events, skipped: [], context: context)
        guard let note = all.first(where: { $0.key == key && $0.day == context.today }) else { return nil }
        let task = tasks.first { $0.name == note.taskName } ?? water
        return NotificationSnoozing.moves(snoozing: note, of: task, until: TestCalendar.date(untilDay, until),
                                          today: TodayTimes(), context: context)
    }

    @Test func aSnoozedHabitMovesItsBlockAndATaskDoesNot() {
        #expect(moves([water], key: waterSlot, at: "09:00", until: "10:00")
            == [TimeMove(task: "Вода", slot: LocalTime("09:00"), time: LocalTime("10:00"))])
        let parcel = makeTask("Parcel") { $0.due = TaskDue("2026-10-21T16:00") }
        #expect(moves([parcel], key: "task|Parcel", at: "16:10", until: "17:10") == nil, "a task's time is written to its line")
    }

    /// Events and reminders are not ours to move: only their notification comes again. Past the end of today nothing moves.
    @Test func eventsRemindersAndMomentsPastTodayMoveNothing() {
        var standup = makeEvent("Standup", from: "15:15", to: "16:15")
        standup.alarmDates = [TestCalendar.date(TestCalendar.wednesday, "15:00")]
        #expect(moves([], key: "event|\(standup.eventIdentifier)|0", at: "15:00", until: "16:00", events: [standup]) == nil)
        let rent = makeReminder("Rent", at: "15:00")
        #expect(moves([], key: "reminder|\(rent.id)", at: "15:00", until: "16:00", reminders: [rent]) == nil)
        #expect(moves([water], key: waterSlot, at: "09:00", until: "04:30", untilDay: "2026-10-22") == nil,
                "tomorrow's logical day")
    }
}

