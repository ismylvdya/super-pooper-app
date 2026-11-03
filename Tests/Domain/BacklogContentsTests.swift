import Foundation
import Testing
@testable import SuperPooperApp

/// The pages left of the pool: Soon holds this week's tasks the shown day does not show, Half year and Someday their
/// own level; never habits, in name order.
struct BacklogContentsTests {
    private let rules = TestConfig.rules.day

    /// On Wednesday an undated this-week task is in the pool, so not in Soon; one dated Friday waits in Soon, as does one
    /// taken out of today (Not today); a timed one on the timeline is not in Soon either.
    @Test func soonHoldsThisWeeksTasksTheDayDoesNotShow() {
        let tasks = [
            makeTask("Pay the internet"),
            makeTask("Fix the shelf") { $0.due = TaskDue("2026-10-23") },
            makeTask("Call the bank") { $0.due = TaskDue("2026-10-21T15:00") },
            makeTask("Wash the car"),
            makeTask("Paint the door", status: .halfYear),
            makeHabit("Water", status: .thisWeek),
        ]
        let plan = DayScenario(tasks: tasks, postponed: ["Wash the car"]).build()
        let soon = BacklogContents.tasks(at: .thisWeek, in: tasks, plan: plan, rules: rules)
        #expect(soon.map(\.name) == ["Fix the shelf", "Wash the car"])
    }

    @Test func halfYearAndSomedayHoldTheirLevel() {
        let tasks = [
            makeTask("Read a novel", status: .someday),
            makeTask("Paint the door", status: .halfYear),
            makeTask("Build a shed", status: .halfYear),
            makeTask("Pay the internet"),
            makeHabit("Stretch", status: .someday),
        ]
        let plan = DayScenario(tasks: tasks).build()
        #expect(BacklogContents.tasks(at: .halfYear, in: tasks, plan: plan, rules: rules).map(\.name) == ["Build a shed", "Paint the door"])
        #expect(BacklogContents.tasks(at: .someday, in: tasks, plan: plan, rules: rules).map(\.name) == ["Read a novel"])
    }
}
