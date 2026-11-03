import Foundation
import Testing
@testable import SuperPooperApp

/// Subtasks of a habit repeat with it: in the day whenever their parent is, marked and skipped per day on their own,
/// gone with the parent, following the parent's rule.
@Suite("Repeatable subtasks")
struct RepeatableSubtasksTests {
    private let parent = makeHabit("Утро — зарядка 🤸", rule: "DTSTART:20260901;FREQ=WEEKLY;BYDAY=MO,WE,FR", status: .habit)

    /// Its own rule says every day; the parent's days decide.
    private func subtask(_ name: String = "Отжимания", of parent: String = "Утро — зарядка 🤸",
                         _ configure: (inout TaskItem) -> Void = { _ in }) -> TaskItem {
        makeHabit(name, status: .habit) { task in
            task.projects = [parent]
            task.habit.repeatable = true
            configure(&task)
        }
    }

    @Test func itIsInTheDaysTheParentIs() {
        let tasks = [parent, subtask()]
        #expect(DayScenario(tasks: tasks).build().dayNames == ["Утро — зарядка 🤸", "Отжимания"])
        #expect(DayScenario(tasks: tasks).build(at: TestCalendar.context("2026-10-20", "10:00")).dayNames.isEmpty)
    }

    @Test func itStandsUnderItsParentInThePool() {
        let plan = DayScenario(tasks: [subtask(), parent]).build()
        #expect(plan.poolNames == ["Утро — зарядка 🤸", "Отжимания"])
        #expect(plan.item(named: "Отжимания")?.depth == 1)
    }

    @Test func skippingTheParentLeavesItButItCanBeSkippedAlone() {
        let tasks = [parent, subtask()]
        #expect(DayScenario(tasks: tasks, skipped: ["Утро — зарядка 🤸"]).build().dayNames == ["Отжимания"])
        #expect(DayScenario(tasks: tasks, skipped: ["Отжимания"]).build().dayNames == ["Утро — зарядка 🤸"])
    }

    @Test func doneTodayIsOnlyToday() {
        let marked = subtask { $0.marks = [LocalDate("2026-10-21"): .done] }
        let wednesday = DayScenario(tasks: [parent, marked]).build()
        #expect(wednesday.item(named: "Отжимания") == nil, "done today, it leaves the pool")
        let friday = DayScenario(tasks: [parent, marked]).build(at: TestCalendar.context("2026-10-23", "10:00"))
        #expect(friday.item(named: "Отжимания")?.isDone == false)
        #expect(marked.isDone(on: LocalDate("2026-10-21")) && !marked.isDone(on: LocalDate("2026-10-23")))
    }

    @Test func aParentLeftOutOfTodayTakesItAlong() {
        var hidden = parent
        hidden.habit.showInToday = false
        #expect(DayScenario(tasks: [hidden, subtask()]).build().dayNames.isEmpty)
    }

    /// A subtask of a repeatable subtask follows it, and so its grandparent's days.
    @Test func aSubtaskOfASubtaskFollowsTheParentsDays() {
        let tasks = [parent, subtask(), subtask("Ещё десять", of: "Отжимания")]
        let tuesday = DayScenario(tasks: tasks).build(at: TestCalendar.context("2026-10-20", "10:00"))
        #expect(tuesday.dayNames.isEmpty)
        #expect(DayScenario(tasks: tasks).build().dayNames.contains("Ещё десять"))
    }

    @Test func parentsOfEachOtherDoNotLoopForever() {
        let first = subtask("A", of: "B")
        let second = subtask("B", of: "A")
        #expect(DayScenario(tasks: [first, second]).build().dayNames == ["A", "B"])
    }

    @Test func anotherDayShowsItWhenTheParentComes() throws {
        let tasks = [parent, subtask()]
        let config = try AppConfig.load(bundle: .main)
        let plan = { (offset: Int) in
            DayPlanning.plan(config: config, settings: TestConfig.defaults, tasks: tasks, events: [], reminders: [],
                             dayState: DayState(day: LocalDate(TestCalendar.wednesday)), context: TestCalendar.context(),
                             dayOffset: offset, eventsKnown: true)
        }
        #expect(plan(1).dayNames.isEmpty, "Thursday")
        #expect(plan(2).dayNames == ["Утро — зарядка 🤸", "Отжимания"], "Friday")
    }

    @Test func aOneOffSubtaskOfAHabitIsNoRepeatableSubtask() {
        let oneOff = makeTask("Купить коврик") { $0.projects = ["Утро — зарядка 🤸"] }
        #expect(!RepeatableSubtasks.isRepeatableSubtask(oneOff, in: [parent, oneOff]))
        #expect(RepeatableSubtasks.isRepeatableSubtask(subtask(), in: [parent]))
    }

    @Test func deletingTheParentTakesIt() {
        let tasks = [parent, subtask()]
        #expect(SubtaskCascade.subtasks(of: parent, in: tasks, change: .deletion).map(\.name) == ["Отжимания"])
        #expect(SubtaskCascade.subtasks(of: parent, in: tasks, change: .completion).isEmpty)
    }

    @Test func withoutOwnTimesItRingsNothing() {
        let planner = NotificationPlanner(horizonDays: 3, limit: 64)
        let planned = planner.plan(tasks: [subtask()], reminders: [], skipped: [],
                                   context: TestCalendar.context(TestCalendar.wednesday, "08:00"))
        #expect(planned.isEmpty)
    }

    // MARK: - The parent's rule

    @Test func aNewParentRuleIsCopiedToEachRepeatableSubtask() {
        let oneOff = makeTask("Купить коврик") { $0.projects = ["Утро — зарядка 🤸"] }
        let following = RepeatableSubtasks.followingRule(of: parent, in: [parent, subtask(), subtask("Приседания"), oneOff])
        #expect(following.map(\.name) == ["Отжимания", "Приседания"])
        #expect(following.allSatisfy { $0.edits == [.recurrence(parent.recurrence)] })
    }

    @Test func aSubtaskWithTheRuleAlreadyIsLeftAlone() {
        let same = subtask { $0.recurrence = parent.recurrence }
        #expect(RepeatableSubtasks.followingRule(of: parent, in: [parent, same]).isEmpty)
    }

    @Test func aParentWithoutARuleLeavesTheSubtasksRuleAlone() {
        var ruleless = parent
        ruleless.recurrence = nil
        #expect(RepeatableSubtasks.followingRule(of: ruleless, in: [ruleless, subtask()]).isEmpty)
    }
}
