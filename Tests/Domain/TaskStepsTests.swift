import Foundation
import Testing
@testable import SuperPooperApp

/// A project done step by step: only its first open subtask is up to do.
@Suite("Steps one by one")
struct TaskStepsTests {
    private func step(_ name: String, of parent: String, order: Int, status: TaskStatus = .thisWeek) -> TaskItem {
        makeTask(name, status: status) {
            $0.projects = [parent]
            $0.subtaskOrder = order
        }
    }

    private var trip: TaskItem { makeTask("Trip") { $0.stepsOneByOne = true } }

    @Test func theLaterStepsWaitWithWhatStandsUnderThem() {
        let tasks = [trip, step("Book", of: "Trip", order: 0), step("Pack", of: "Trip", order: 1),
                     step("Socks", of: "Pack", order: 0), step("Go", of: "Trip", order: 2)]
        #expect(TaskSteps.waiting(in: tasks) == ["Pack", "Socks", "Go"])
    }

    @Test func aDoneStepLetsTheNextOneUp() {
        let tasks = [trip, step("Book", of: "Trip", order: 0, status: .done), step("Pack", of: "Trip", order: 1),
                     step("Go", of: "Trip", order: 2)]
        #expect(TaskSteps.waiting(in: tasks) == ["Go"])
    }

    @Test func withoutTheSwitchEverySubtaskIsUp() {
        let tasks = [makeTask("Trip"), step("Book", of: "Trip", order: 0), step("Pack", of: "Trip", order: 1)]
        #expect(TaskSteps.waiting(in: tasks).isEmpty)
    }

    @Test func aWaitingStepIsNotInTheDay() {
        let today = TaskDue(day: LocalDate(TestCalendar.wednesday))
        var parent = trip
        parent.due = today
        let tasks = [parent, step("Book", of: "Trip", order: 0), step("Pack", of: "Trip", order: 1)].map { task in
            var task = task
            task.due = today
            return task
        }
        let plan = DayScenario(tasks: tasks).build(at: TestCalendar.context(TestCalendar.wednesday, "08:00"))
        #expect(plan.poolNames.contains("Book") && !plan.poolNames.contains("Pack"))
    }

    @Test func theSwitchIsInTheLine() {
        let format = TestConfig.decode(TaskFileFormat.self, TaskFileFormat.fileName)
        let entry = TaskEntry(line: "- [ ] Trip 🪜", format: format)
        #expect(entry?.stepsOneByOne == true && entry?.name == "Trip")
        #expect(entry?.line(format: format) == "- [ ] Trip 🪜")
    }
}
