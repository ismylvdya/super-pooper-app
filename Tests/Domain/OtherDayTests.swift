import Foundation
import Testing
@testable import SuperPooperApp

/// Another day browsed on Today (Thursday 2026-10-22, seen on Wednesday at 13:25): the same day rules,
/// with "past" and blocking measured from the real now, and links resolved among all tasks.
@Suite("Other days")
@MainActor
struct OtherDayTests {
    private let config: AppConfig
    private let call = makeEvent("Early call", day: "2026-10-22", from: "07:00", to: "07:30")

    init() throws {
        config = try AppConfig.load(bundle: .main)
    }

    private func tomorrow(_ tasks: [TaskItem], events: [CalendarEvent] = []) -> DayPlan {
        DayPlanning.plan(config: config, settings: TestConfig.defaults, tasks: tasks, events: events, reminders: [],
                         dayState: DayState(day: LocalDate(TestCalendar.wednesday)), context: TestCalendar.context(), dayOffset: 1,
                         eventsKnown: true)
    }

    @Test func tomorrowsEventsAreNotPastYet() throws {
        let plan = tomorrow([], events: [call])
        let slot = try #require(plan.eventSlot("Early call"))
        #expect(!slot.isPast)
    }

    /// What is dated that day in any open list, Someday too; an undated or archived task is not.
    @Test func whatIsDatedThatDayIsShown() {
        let waiting = makeTask("Waiting", status: .someday) { $0.due = TaskDue("2026-10-22") }
        let planned = makeTask("Planned") { $0.due = TaskDue("2026-10-22") }
        let archived = makeTask("Old", status: .archived) { $0.due = TaskDue("2026-10-22") }
        #expect(tomorrow([waiting, planned, archived, makeTask("Undated")]).dayNames == ["Planned", "Waiting"] as Set)
    }

    /// A habit stands on the day its line in the file does: one open today is not on tomorrow, though its rule has that
    /// day; one done today, or due only tomorrow, is. Only those shown in Today, and none that comes up every day (D-187).
    @Test func habitsStandOnTheDayOfTheirLine() {
        let thursday = LocalDate("2026-10-22")
        let openToday = makeHabit("Water", rule: Self.twiceAWeek, status: .habit) { $0.nextLine = TaskDue(day: LocalDate(TestCalendar.wednesday)) }
        let doneToday = makeHabit("Tea", rule: Self.twiceAWeek, status: .habit) { $0.nextLine = TaskDue(day: thursday) }
        let daily = makeHabit("Juice", status: .habit) { $0.nextLine = TaskDue(day: thursday) }
        let everyThreeDays = makeHabit("Laundry", rule: "DTSTART:20261019;FREQ=DAILY;INTERVAL=3", status: .habit) { $0.nextLine = TaskDue(day: thursday) }
        let hidden = makeHabit("Hidden", status: .habit) {
            $0.habit.showInToday = false
            $0.nextLine = TaskDue(day: thursday)
        }
        #expect(tomorrow([openToday, doneToday, everyThreeDays, hidden, daily]).dayNames == ["Tea", "Laundry"] as Set)
    }

    /// Not every day: on Mondays and Thursdays.
    private static let twiceAWeek = "DTSTART:20261019;FREQ=WEEKLY;BYDAY=MO,TH"

    /// Another day's pool leaves out a habit that comes up every day; with a time it still stands on that day's timeline.
    @Test func aDailyHabitIsOnlyOnAnotherDaysTimeline() {
        let thursday = LocalDate("2026-10-22")
        let untimed = makeHabit("Stretch", status: .habit) { $0.nextLine = TaskDue(day: thursday) }
        let timed = makeHabit("Run", status: .habit) {
            $0.reminderTimes = [LocalTime(hour: 7, minute: 0)!]
            $0.nextLine = TaskDue(day: thursday, time: LocalTime(hour: 7, minute: 0))
        }
        let plan = tomorrow([untimed, timed])
        #expect(plan.pool.isEmpty)
        #expect(plan.timeline.count == 1)
    }

    /// Which repeat rules come up every day.
    @Test func everyDayIsDailyWithoutAGapOrAllSevenWeekdays() {
        let rule = { (text: String) -> RecurrenceRule? in
            if case .success(let parsed) = RecurrenceCodec.parse(text) { return parsed }
            return nil
        }
        #expect(rule("FREQ=DAILY")?.isEveryDay == true)
        #expect(rule("FREQ=WEEKLY;BYDAY=MO,TU,WE,TH,FR,SA,SU")?.isEveryDay == true)
        #expect(rule("FREQ=DAILY;INTERVAL=2")?.isEveryDay == false)
        #expect(rule("FREQ=WEEKLY;BYDAY=MO,TH")?.isEveryDay == false)
        #expect(rule("FREQ=DAILY;BYDAY=MO,TU,WE,TH,FR")?.isEveryDay == false)
    }

    /// A line with a time puts the habit on that day's timeline, one without in its pool.
    @Test func aHabitsLineSaysPoolOrTimeline() throws {
        let thursday = LocalDate("2026-10-22")
        let timed = makeHabit("Gym", status: .habit) {
            $0.reminderTimes = [LocalTime(hour: 18, minute: 0)!]
            $0.nextLine = TaskDue(day: thursday, time: LocalTime(hour: 18, minute: 0))
        }
        let carried = makeHabit("Read", rule: Self.twiceAWeek, status: .habit) {
            $0.reminderTimes = [LocalTime(hour: 19, minute: 0)!]
            $0.nextLine = TaskDue(day: thursday)
        }
        let plan = tomorrow([timed, carried])
        #expect(plan.pool.map { $0.id } == ["Read"])
        #expect(plan.timeline.count == 1)
    }

    /// Another day's pool stands in sections too: Morning and Evening by a task's routine, the rest in Day.
    @Test func anotherDayHasTheSectionsByRoutine() throws {
        let morning = makeHabit("Water", rule: Self.twiceAWeek, status: .habit) {
            $0.habit.timeOfDay = .morning
            $0.nextLine = TaskDue(day: LocalDate("2026-10-22"))
        }
        let planned = makeTask("Planned") { $0.due = TaskDue("2026-10-22") }
        let plan = tomorrow([morning, planned])
        #expect(plan.sections.map(\.id) == ["morning", "day"])
        #expect(plan.sections.map { $0.items.map(\.id) } == [["Water"], ["Planned"]])
    }

    /// A habit left undone is overdue on today; the next day of its rule shows it on that day, as one coming up there.
    /// One still due today is not on its later days: only its nearest one counts.
    @Test func anOverdueHabitStandsOnTheNextDayOfItsRule() {
        let wednesday = LocalDate(TestCalendar.wednesday)
        let overdue = makeHabit("Laundry", rule: "DTSTART:20261019;FREQ=DAILY;INTERVAL=3", status: .habit) {
            $0.isOverdue = true
            $0.nextLine = TaskDue(day: wednesday)
        }
        let dueToday = makeHabit("Plants", rule: "DTSTART:20261019;FREQ=DAILY;INTERVAL=3", status: .habit) {
            $0.nextLine = TaskDue(day: wednesday)
        }
        #expect(tomorrow([overdue, dueToday]).dayNames == ["Laundry"] as Set)
    }
}
