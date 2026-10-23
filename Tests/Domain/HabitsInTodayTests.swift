import Foundation
import Testing
@testable import SuperPooper

/// Which habits reach Today, archived notes leaving the day, the part-of-day sort and all-day events.
@Suite("Habits in Today")
struct HabitsInTodayTests {
    private func habit(_ name: String, times: [String] = [], showInToday: Bool = true,
                       _ configure: (inout TaskNote) -> Void = { _ in }) -> TaskNote {
        makeHabit(name, status: .habit) { task in
            task.reminderTimes = times.map { LocalTime($0) }
            task.habit.showInToday = showInToday
            configure(&task)
        }
    }

    // MARK: - Show in Today

    @Test func aHabitSwitchedOffStaysOutOfThePoolAndTheTimeline() {
        let plan = DayScenario(tasks: [habit("Hidden", showInToday: false), habit("Hidden timed", times: ["09:00"], showInToday: false)]).build()
        #expect(plan.dayNames.isEmpty)
    }

    @Test func aHabitSwitchedOnIsInThePoolOrOnTheTimeline() {
        let plan = DayScenario(tasks: [habit("Pool"), habit("Timed", times: ["09:00"])]).build()
        #expect(plan.poolNames == ["Pool"])
        #expect(plan.timelineTaskNames == ["Timed"])
    }

    @Test func aHiddenHabitIsStillNotified() {
        let planner = NotificationPlanner(horizonDays: 1, limit: 64)
        let planned = planner.plan(tasks: [habit("Hidden", times: ["21:00"], showInToday: false)], reminders: [], skipped: [],
                                   context: TestCalendar.context(TestCalendar.wednesday, "08:00"))
        #expect(planned.map(\.taskName) == ["Hidden"])
    }

    @Test func notesWithoutTheKeyStayVisible() throws {
        let reader = TaskNoteReader(mapping: TestConfig.mapping, taskTag: "t", calendar: TestCalendar.calendar)
        let note = reader.task(from: try FrontmatterDocument(text: "---\ntags: [t]\nstatus: habit\n---\n"), name: "Old", relativePath: "Old.md")
        #expect(note.habit.showInToday)
    }

    // MARK: - Archive

    @Test func anArchivedHabitLeavesTheDayAndTheNotifications() {
        let archived = habit("Archived", times: ["21:00"]) { $0.status = .archived }
        let pooled = habit("Archived pool") { $0.status = .archived }
        #expect(DayScenario(tasks: [archived, pooled]).build().dayNames.isEmpty)
        let planner = NotificationPlanner(horizonDays: 2, limit: 64)
        #expect(planner.plan(tasks: [archived], reminders: [], skipped: [], context: TestCalendar.context(TestCalendar.wednesday, "08:00")).isEmpty)
    }

    @Test func anArchivedTaskLeavesTheDayAndTheNotifications() {
        let task = makeTask("Archived task", status: .archived) { $0.due = TaskDue("2026-10-21T18:00") }
        #expect(DayScenario(tasks: [task]).build().dayNames.isEmpty)
        let planner = NotificationPlanner(horizonDays: 2, limit: 64)
        #expect(planner.plan(tasks: [task], reminders: [], skipped: [], context: TestCalendar.context(TestCalendar.wednesday, "08:00")).isEmpty)
    }

    @Test func anArchivedHabitReportsNoProblems() {
        let broken = habit("Broken") { task in
            task.status = .archived
            task.problems = [.unknownRecurrence("FREQ=NOPE")]
        }
        #expect(DayScenario(tasks: [broken]).build().problems.isEmpty)
    }

    // MARK: - Part of the day

    @Test(arguments: [("08:00", ["Morning", "Any", "Evening"]), ("14:00", ["Any", "Evening", "Morning"]), ("20:00", ["Evening", "Any", "Morning"])])
    func habitsOfTheCurrentPartGoUp(time: String, expected: [String]) {
        let tasks = [habit("Any"), habit("Evening") { $0.habit.timeOfDay = .evening }, habit("Morning") { $0.habit.timeOfDay = .morning }]
        let names = DayScenario(tasks: tasks).build(at: TestCalendar.context(TestCalendar.wednesday, time)).poolNames
        #expect(names == expected)
    }

    @Test func afterMidnightIsStillEvening() {
        let rules = TestConfig.rules.day
        #expect(rules.partOfDay(TestCalendar.context("2026-10-22", "01:30")) == .evening)
        #expect(rules.partOfDay(TestCalendar.context(TestCalendar.wednesday, "04:30")) == .morning)
        #expect(rules.partOfDay(TestCalendar.context(TestCalendar.wednesday, "12:00")) == .day)
    }

    // MARK: - All-day events

    @Test func tomorrowsAllDayEventIsNotToday() {
        let today = makeEvent("Today off", from: "00:00", to: "23:59", allDay: true)
        let tomorrow = makeEvent("Tomorrow off", day: "2026-10-22", from: "00:00", to: "23:59", allDay: true)
        let plan = DayScenario(tasks: [], events: [today, tomorrow]).build(at: TestCalendar.context(TestCalendar.wednesday, "23:30"))
        #expect(plan.allDayEvents.map(\.title) == ["Today off"])
    }

    @Test func aMultiDayAllDayEventCoversEveryDay() {
        let trip = CalendarEvent(eventIdentifier: "trip", title: "Trip", start: TestCalendar.date("2026-10-20"),
                                 end: TestCalendar.date("2026-10-23"), isAllDay: true, calendarID: "c", calendarTitle: "C", colorHex: "#000000")
        #expect(trip.covers(LocalDate("2026-10-22"), calendar: TestCalendar.calendar))
        #expect(!trip.covers(LocalDate("2026-10-23"), calendar: TestCalendar.calendar))
        #expect(!trip.covers(LocalDate("2026-10-19"), calendar: TestCalendar.calendar))
    }
}
