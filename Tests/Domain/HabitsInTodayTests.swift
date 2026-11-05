import Foundation
import Testing
@testable import SuperPooperApp

/// Which habits reach Today, archived notes leaving the day, the part-of-day sort and all-day events.
@Suite("Habits in Today")
struct HabitsInTodayTests {
    private func habit(_ name: String, times: [String] = [], showInToday: Bool = true,
                       _ configure: (inout TaskItem) -> Void = { _ in }) -> TaskItem {
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

    /// The hour no longer moves routines: their sections place them, the same all day.
    @Test func theHourDoesNotMoveRoutines() {
        let tasks = [habit("Any"), habit("Evening") { $0.habit.timeOfDay = .evening }, habit("Morning") { $0.habit.timeOfDay = .morning }]
        let orders = ["08:00", "14:00", "20:00"].map { DayScenario(tasks: tasks).build(at: TestCalendar.context(TestCalendar.wednesday, $0)).poolNames }
        #expect(Set(orders).count == 1)
    }

    // MARK: - All-day events

    @Test func tomorrowsAllDayEventIsNotToday() {
        let today = makeEvent("Today off", from: "00:00", to: "23:59", allDay: true)
        let tomorrow = makeEvent("Tomorrow off", day: "2026-10-22", from: "00:00", to: "23:59", allDay: true)
        let plan = DayScenario(tasks: [], events: [today, tomorrow]).build(at: TestCalendar.context(TestCalendar.wednesday, "23:30"))
        #expect(plan.allDayEvents.map(\.title) == ["Today off"])
    }

    /// Only Morning and Evening are routines; each keeps its order in its own setting, and the day reads both from there.
    @Test func eachRoutineHasItsSetting() {
        #expect(HabitTimeOfDay.allCases == [.morning, .evening])
        var habits = TestConfig.defaults.habits
        for (part, names) in zip(HabitTimeOfDay.allCases, [["M"], ["E"]]) {
            habits[keyPath: AppSettings.Habits.routine(part)] = names
        }
        #expect(habits.morningRoutine == ["M"] && habits.eveningRoutine == ["E"])
        #expect(HabitTimeOfDay.allCases.map(habits.routines.order) == [["M"], ["E"]])
    }

    /// All-day bars go by name as everything else does (`NameOrder`): letter case does not matter, numbers count as numbers.
    @Test func allDayEventsAreInNameOrder() {
        let events = ["day 10", "Day 9", "anniversary"].map { makeEvent($0, from: "00:00", to: "23:59", allDay: true) }
        let plan = DayScenario(tasks: [], events: events).build()
        #expect(plan.allDayEvents.map(\.title) == ["anniversary", "Day 9", "day 10"])
    }

    @Test func aMultiDayAllDayEventCoversEveryDay() {
        let trip = CalendarEvent(eventIdentifier: "trip", title: "Trip", start: TestCalendar.date("2026-10-20"),
                                 end: TestCalendar.date("2026-10-23"), isAllDay: true, calendarID: "c", calendarTitle: "C", colorHex: "#000000")
        #expect(trip.covers(LocalDate("2026-10-22"), calendar: TestCalendar.calendar))
        #expect(!trip.covers(LocalDate("2026-10-23"), calendar: TestCalendar.calendar))
        #expect(!trip.covers(LocalDate("2026-10-19"), calendar: TestCalendar.calendar))
    }
}

/// Routines, the user's pool order and postponed tasks.
@Suite("Routines and pool order")
struct RoutineOrderTests {
    private func habit(_ name: String, _ part: HabitTimeOfDay?) -> TaskItem {
        makeHabit(name, status: .habit) { $0.habit.timeOfDay = part }
    }

    @Test func theMorningRoutineIsFirstAllDayLong() {
        let tasks = [makeTask("High") { $0.isHighPriority = true }, habit("Evening", .evening), habit("Morning", .morning)]
        let names = DayScenario(tasks: tasks).build(at: TestCalendar.context(TestCalendar.wednesday, "20:00")).poolNames
        #expect(names.first == "Morning")
    }

    @Test func routinesFollowTheUsersOrder() {
        var scenario = DayScenario(tasks: [habit("A stretch", .morning), habit("B shower", .morning), habit("C coffee", .morning)])
        scenario.routines = HabitRoutines(morning: ["C coffee", "A stretch"])
        #expect(scenario.build().poolNames == ["C coffee", "A stretch", "B shower"])
    }

    @Test func extraLinesGrowWithTheEstimate() {
        let pool = TestConfig.rules.pool
        #expect(pool.extraLines(forEstimate: 15) == 0)
        #expect(pool.extraLines(forEstimate: 60) == 1)
        #expect(pool.extraLines(forEstimate: 240) == 2)
    }
}

@Suite("Routine plates")
struct PoolSegmentsTests {
    private func item(_ name: String, _ part: HabitTimeOfDay?, habit: Bool = true, done: Bool = false) -> DayItem {
        let task = habit ? makeHabit(name, status: .habit) { $0.habit.timeOfDay = part } : makeTask(name)
        return DayItem(task: task, state: done ? .marked(.done) : .open, problems: [])
    }

    @Test func neighbouringHabitsOfOneRoutineShareAPlate() {
        let segments = PoolSegments.make([item("A", .morning), item("B", .morning), item("C", nil, habit: false),
                                          item("D", .evening), item("E", .evening), item("F", .morning, done: true)])
        #expect(segments.map { $0.items.map(\.id) } == [["A", "B"], ["C"], ["D", "E"], ["F"]])
    }

    /// A worm is one shared plate, its members' subtasks on it; a routine's habits beside it keep a plate of their own.
    @Test func aWormIsOneSharedPlate() {
        var subtask = item("C1", nil, habit: false)
        subtask.depth = 1
        let worms = [DayWorm(id: "w", members: ["A", "C"])]
        let segments = PoolSegments.make([item("A", .morning), item("C", nil, habit: false), subtask, item("B", .morning),
                                          item("D", .morning)], worms: worms)
        #expect(segments.map { $0.items.map(\.id) } == [["A", "C", "C1"], ["B", "D"]])
        let worm: [String?] = segments.map { $0.wormID }
        #expect(worm == ["w", nil])
        #expect(segments.allSatisfy { $0.isShared })
        #expect(PoolSegments.make([item("A", nil, habit: false)], worms: worms).first?.isShared == false, "one member left is a plain plate")
    }

    @Test func theEveningRoutineSharesAPlateToo() {
        let segments = PoolSegments.make([item("A", .evening), item("B", .evening), item("C", .morning)])
        #expect(segments.map { $0.items.map(\.id) } == [["A", "B"], ["C"]])
    }

    @Test func eachRoutineKeepsItsOwnOrder() {
        let routines = HabitRoutines(morning: ["M2", "M1"], evening: ["E2", "E1"])
        #expect(routines.position(of: makeHabit("E1", status: .habit) { $0.habit.timeOfDay = .evening }) == 1)
        #expect(routines.position(of: makeHabit("M2", status: .habit) { $0.habit.timeOfDay = .morning }) == 0)
        #expect(routines.position(of: makeHabit("Any", status: .habit)) == nil)
    }
}
