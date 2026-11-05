import Foundation
import Testing
@testable import SuperPooperApp

/// Edits made on the day's view of a task with a time zone of its own (a Jakarta task on a Belgrade phone, Wednesday
/// 2026-10-21 13:25): the day shows its times on the phone's clock, the note keeps them in Jakarta time.
@MainActor
struct ZonedTaskEditsTests {
    private func makeModel(_ tasks: [TaskItem]) throws -> AppModel {
        try #require(PreviewModel.make(calendar: FixedCalendar(current: TestCalendar.calendar),
                                       clock: FixedClock(now: TestCalendar.date(TestCalendar.wednesday, "13:25")),
                                       tasks: tasks)).model
    }

    private func jakartaTask(_ name: String, due: String?, status: TaskStatus = .thisWeek) -> TaskItem {
        makeTask(name, status: status) { task in
            task.timeZone = "Asia/Jakarta"
            task.due = due.map(TaskDue.init)
        }
    }

    @Test func aDropOnTheTimelineIsWrittenInJakartaTime() async throws {
        let model = try makeModel([jakartaTask("Standup", due: "2026-10-21")])
        await model.schedule("Standup", at: TestCalendar.date(TestCalendar.wednesday, "16:00"))
        #expect(model.task(named: "Standup")?.due == TaskDue("2026-10-21T21:00"))
        let slot = try #require(model.plan(at: model.clock.now).slot("Standup"))
        #expect(clockTime(slot.start) == "16:00")
    }

    /// 08:00 on the 22nd in Jakarta is 03:00 in Belgrade: on today's timeline. Back in the pool it stays today.
    @Test func backToThePoolKeepsTheDayItWasShownOn() async throws {
        let model = try makeModel([jakartaTask("Standup", due: "2026-10-22T08:00")])
        await model.unschedule("Standup", poolOrder: [])
        #expect(model.task(named: "Standup")?.due == TaskDue("2026-10-21"))
    }

    /// Not today takes the date away, whatever zone it is kept in.
    @Test func notTodayTakesAZonedTasksDateAway() async throws {
        let model = try makeModel([jakartaTask("Call", due: "2026-10-22T01:00")])
        await model.perform(.notToday, on: "Call")
        #expect(model.task(named: "Call")?.due == nil)
    }

    @Test func aDatePickedInThisWeekIsWrittenInJakartaTime() async throws {
        let model = try makeModel([jakartaTask("Call", due: nil)])
        await model.setLocalDue(TaskDue("2026-10-22T09:00"), of: "Call")
        #expect(model.task(named: "Call")?.due == TaskDue("2026-10-22T14:00"))
    }

    /// 05:00 on Monday in Jakarta is 23:00 on Sunday in Belgrade: this week on the phone, so it joins this week.
    @Test func autoPromotionJudgesTheDayOnThePhonesClock() async throws {
        let model = try makeModel([jakartaTask("Visa", due: "2026-10-26T05:00", status: .halfYear)])
        await model.sync(announce: false)
        #expect(model.task(named: "Visa")?.status == .thisWeek)
    }

    /// A zone added on the date sheet leaves the time as it is: 15:00 stays 15:00, now in that zone, in the note and on the chip.
    @Test func aZoneAddedToATimeKeepsTheTime() async throws {
        let model = try makeModel([makeTask("Call") { $0.due = TaskDue("2026-10-21T15:00") }])
        let task = try #require(model.task(named: "Call"))
        var pick = DuePick(task: task, today: model.context().today)
        #expect(pick.time == LocalTime("15:00"))
        pick.zone = "Asia/Bangkok"
        await model.edit("Call") { pick.edits(from: $0) }
        let saved = try #require(model.task(named: "Call"))
        #expect(saved.due == TaskDue("2026-10-21T15:00") && saved.timeZone == "Asia/Bangkok")
        #expect(DateChip.shown(of: saved, context: model.context()).time == LocalTime("15:00"))
        #expect(DuePick(task: saved, today: model.context().today).time == LocalTime("15:00"))
    }

    /// The same on a new task's draft, as a "+" dropped on the timeline makes it.
    @Test func aZoneAddedOnADraftKeepsTheTime() {
        var draft = NoteDraft(status: .thisWeek, changes: [.due(TaskDue("2026-10-21T15:00"))])
        var pick = DuePick(task: draft.note, today: LocalDate(TestCalendar.wednesday))
        pick.zone = "Asia/Bangkok"
        draft.apply(pick.edits(from: draft.note))
        #expect(draft.note.due == TaskDue("2026-10-21T15:00") && draft.note.timeZone == "Asia/Bangkok")
    }
}
