import Foundation
import Testing
@testable import SuperPooperApp

/// Pool sorting with the real `sort.json` order and `rules.json` defaults.
/// Wednesday 2026-10-21; Friday is the 23rd, Sunday the 25th; the energy hour is 14:00.
@Suite("Pool sorting")
struct PoolSorterTests {
    private let morning = TestCalendar.context(TestCalendar.wednesday, "10:00")

    @Test func configListsTheSpecCriteriaInSpecOrder() {
        #expect(TestConfig.sort.pool == [.morningRoutine, .habitsFirst, .habitTimeOfDay, .routineOrder, .dueToday, .highPriority, .nearestDueThisWeek,
                                         .energyBeforeEnergyHour, .unpleasantFirst, .shortFirst, .olderFirst])
    }

    // MARK: - Each criterion beats every criterion below it

    @Test func habitsWithoutTimeComeFirst() {
        let habit = makeHabit("Habit") { $0.timeEstimate = 240; $0.dateCreated = TestCalendar.date("2026-10-20") }
        let rest = favoredByEverythingBelow(.habitsFirst)
        #expect(sortedNames([rest, habit], at: morning) == ["Habit", "Rest"])
    }

    @Test func aTimedHabitIsNotTreatedAsAnUntimedOne() {
        let timed = makeHabit("Timed habit", time: "09:00")
        let short = makeTask("Short") { $0.timeEstimate = 2 }
        #expect(sortedNames([timed, short], at: morning) == ["Short", "Timed habit"])
    }

    @Test(arguments: ["2026-10-21", "2026-10-21T18:00"])
    func dueTodayBeatsEverythingBelow(due: String) {
        let today = makeTask("Due today", created: "2026-10-20") { $0.due = TaskDue(due); $0.timeEstimate = 240 }
        let rest = favoredByEverythingBelow(.dueToday)
        #expect(sortedNames([rest, today], at: morning) == ["Due today", "Rest"])
    }

    @Test func highPriorityBeatsEverythingBelow() {
        let high = makeTask("High", created: "2026-10-20") { $0.isHighPriority = true; $0.timeEstimate = 240 }
        let rest = favoredByEverythingBelow(.highPriority)
        #expect(sortedNames([rest, high], at: morning) == ["High", "Rest"])
    }

    @Test func nearestDueThisWeekBeatsEverythingBelow() {
        let friday = makeTask("Friday", created: "2026-10-20") { $0.due = TaskDue("2026-10-23"); $0.timeEstimate = 240 }
        let rest = favoredByEverythingBelow(.nearestDueThisWeek)
        #expect(sortedNames([rest, friday], at: morning) == ["Friday", "Rest"])
    }

    @Test func nearerDueThisWeekGoesEarlierAndNextWeekCountsAsNoDue() {
        let sunday = makeTask("Sunday") { $0.due = TaskDue("2026-10-25") }
        let thursday = makeTask("Thursday") { $0.due = TaskDue("2026-10-22T18:00") }
        let nextMonday = makeTask("Next Monday", created: "2026-10-11") { $0.due = TaskDue("2026-10-26") }
        let noDue = makeTask("No due", created: "2026-10-01")
        #expect(sortedNames([nextMonday, noDue, sunday, thursday], at: morning)
            == ["Thursday", "Sunday", "No due", "Next Monday"])
    }

    @Test func needEnergyGoesUpBeforeTheEnergyHour() {
        let energy = makeTask("Energy", created: "2026-10-20") { $0.feel = .needEnergy; $0.timeEstimate = 240 }
        let rest = favoredByEverythingBelow(.energyBeforeEnergyHour)
        #expect(sortedNames([rest, energy], at: TestCalendar.context(TestCalendar.wednesday, "13:59")) == ["Energy", "Rest"])
    }

    @Test(arguments: ["14:00", "18:30", "23:59"])
    func needEnergyGoesDownFromTheEnergyHour(time: String) {
        let energy = makeTask("Energy", created: "2026-01-01") { $0.feel = .needEnergy; $0.timeEstimate = 2 }
        let plain = makeTask("Plain", created: "2026-10-20") { $0.feel = .pleasant; $0.timeEstimate = 240 }
        #expect(sortedNames([energy, plain], at: TestCalendar.context(TestCalendar.wednesday, time)) == ["Plain", "Energy"])
    }

    @Test func pleasantWaitsBehindEverythingBelow() {
        let pleasant = makeTask("Pleasant", created: "2026-01-01") { $0.feel = .pleasant; $0.timeEstimate = 2 }
        let rest = makeTask("Rest", created: "2026-10-20") { $0.timeEstimate = 240 }
        #expect(sortedNames([pleasant, rest], at: morning) == ["Rest", "Pleasant"])
    }

    @Test func afterTheEnergyHourPleasantGoesBehindNeutralButBeforeNeedingEnergy() {
        let pleasant = makeTask("Pleasant", created: "2026-10-01") { $0.feel = .pleasant }
        let unset = makeTask("Unset", created: "2026-10-02")
        let energy = makeTask("Energy", created: "2026-10-03") { $0.feel = .needEnergy }
        #expect(sortedNames([pleasant, energy, unset], at: TestCalendar.context(TestCalendar.wednesday, "14:00")) == ["Unset", "Pleasant", "Energy"])
    }

    @Test func shorterBeatsOlder() {
        let short = makeTask("Short", created: "2026-10-20") { $0.timeEstimate = 2 }
        let rest = favoredByEverythingBelow(.shortFirst)
        #expect(sortedNames([rest, short], at: morning) == ["Short", "Rest"])
    }

    @Test func anEmptyEstimateCountsAsFifteenMinutes() {
        let hour = makeTask("Hour", created: "2026-01-01") { $0.timeEstimate = 60 }
        let empty = makeTask("Empty", created: "2026-05-01")
        let quarter = makeTask("Quarter", created: "2026-03-01") { $0.timeEstimate = 15 }
        let two = makeTask("Two", created: "2026-10-20") { $0.timeEstimate = 2 }
        #expect(sortedNames([hour, empty, quarter, two], at: morning) == ["Two", "Quarter", "Empty", "Hour"])
    }

    @Test func olderGoesFirstAndMissingCreationDateGoesLast() {
        let newer = makeTask("Newer", created: "2026-10-20")
        let older = makeTask("Older", created: "2026-02-01")
        let unknown = makeTask("Unknown") { $0.dateCreated = nil }
        #expect(sortedNames([unknown, newer, older], at: morning) == ["Older", "Newer", "Unknown"])
    }

    @Test func fullTiesFallBackToTheNameWithNumbersComparedAsNumbers() {
        let names = ["Позвонить", "Шаг 10", "Вынести мусор", "Шаг 2"]
        #expect(sortedNames(names.map { makeTask($0) }, at: morning) == ["Вынести мусор", "Позвонить", "Шаг 2", "Шаг 10"])
    }

    // MARK: - Links and done tasks

    @Test func aTaskIsNeverAboveItsPreviousTasks() {
        let third = makeTask("C third") { $0.isHighPriority = true; $0.previousTasks = ["B second"] }
        let second = makeTask("B second") { $0.due = TaskDue("2026-10-22"); $0.previousTasks = ["A first"] }
        let first = makeTask("A first")
        let unrelated = makeTask("X unrelated") { $0.timeEstimate = 2 }
        #expect(sortedNames([third, second, first, unrelated], at: morning) == ["X unrelated", "A first", "B second", "C third"])
    }

    @Test func habitsComeInTheOrderOfTheirLinks() {
        let breakfast = makeHabit("A breakfast") { $0.previousTasks = ["B shower"] }
        let shower = makeHabit("B shower") { $0.previousTasks = ["C workout"] }
        let workout = makeHabit("C workout") { $0.timeEstimate = 240 }
        let urgent = makeTask("Urgent") { $0.due = TaskDue("2026-10-21"); $0.isHighPriority = true }
        #expect(sortedNames([urgent, breakfast, shower, workout], at: morning)
            == ["C workout", "B shower", "A breakfast", "Urgent"])
    }

    @Test func aPredecessorOutsideThePoolDoesNotMoveTheTask() {
        let task = makeTask("Follow-up") { $0.timeEstimate = 2; $0.previousTasks = ["Somewhere else"] }
        let other = makeTask("Other")
        let items = [item(task), item(other)]
        let graph = TaskGraph(tasks: [task, other, makeTask("Somewhere else")])
        #expect(sorter.sorted(items, graph: graph, context: morning).map(\.id) == ["Follow-up", "Other"])
    }

    @Test func doneTodayGoesLastKeepingTheirOwnOrder() {
        let doneHigh = makeTask("Done high", status: .done) { $0.isHighPriority = true }
        let donePlain = makeTask("Done plain", status: .done)
        let open = makeTask("Open") { $0.timeEstimate = 240 }
        #expect(sortedNames([donePlain, doneHigh, open], done: ["Done high", "Done plain"], at: morning)
            == ["Open", "Done high", "Done plain"])
    }

    @Test func doneTasksAlsoStayAfterTheirPreviousTasks() {
        let workout = makeHabit("C workout")
        let shower = makeHabit("B shower") { $0.previousTasks = ["C workout"] }
        let breakfast = makeHabit("A breakfast") { $0.previousTasks = ["B shower"] }
        #expect(sortedNames([breakfast, shower, workout], done: ["C workout", "B shower"], at: morning)
            == ["A breakfast", "C workout", "B shower"])
    }

    // MARK: - Helpers

    private var sorter: PoolSorter { PoolSorter(criteria: TestConfig.sort.pool, rules: TestConfig.rules.day) }

    private func item(_ task: TaskNote, done: Bool = false) -> DayItem {
        DayItem(task: task, state: done ? .marked(.done) : .open, blockers: [], problems: [])
    }

    private func sortedNames(_ tasks: [TaskNote], done: Set<String> = [], at context: DayContext) -> [String] {
        let items = tasks.map { item($0, done: done.contains($0.name)) }
        return sorter.sorted(items, graph: TaskGraph(tasks: tasks), context: context).map(\.id)
    }

    /// "Rest": a task that every criterion after `criterion` prefers (and that ties on the ones before it).
    private func favoredByEverythingBelow(_ criterion: PoolSortCriterion) -> TaskNote {
        let below = TestConfig.sort.pool.drop { $0 != criterion }.dropFirst()
        return makeTask("Rest", created: "2026-01-01") { task in
            for lower in below {
                switch lower {
                case .habitsFirst, .habitTimeOfDay, .morningRoutine, .routineOrder: break
                case .dueToday: task.due = TaskDue("2026-10-21")
                case .highPriority: task.isHighPriority = true
                case .nearestDueThisWeek: if task.due == nil { task.due = TaskDue("2026-10-22") }
                case .energyBeforeEnergyHour: task.feel = .needEnergy
                case .unpleasantFirst: break
                case .shortFirst: task.timeEstimate = 2
                case .olderFirst: break
                }
            }
        }
    }
}
