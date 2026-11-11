import Foundation
import Testing
@testable import SuperPooperApp

/// A task shown one at a time: in the pool only its next action, under the name of the task on top.
@Suite("Show one at a time")
struct TaskStepsTests {
    private func step(_ name: String, of parent: String, order: Int, status: TaskStatus = .thisWeek) -> TaskItem {
        makeTask(name, status: status) {
            $0.projects = [parent]
            $0.subtaskOrder = order
        }
    }

    private var trip: TaskItem { makeTask("Trip") { $0.stepsOneByOne = true } }
    private var tasks: [TaskItem] {
        [trip, step("Pack", of: "Trip", order: 0), step("Socks", of: "Pack", order: 0), step("Charger", of: "Pack", order: 1),
         step("Go", of: "Trip", order: 1)]
    }

    @Test func theNextActionIsTheFirstOpenOneAllTheWayDown() {
        let plan = TaskSteps.plan(in: tasks)
        #expect(plan.projectOf == ["Socks": "Trip"])
        #expect(plan.projects == ["Trip"])
        #expect(plan.waiting == ["Pack", "Charger", "Go"])
    }

    @Test func aTaskInsideOneShownOneAtATimeFollowsTheOneOnTop() {
        var all = tasks
        all[1].stepsOneByOne = true
        #expect(TaskSteps.plan(in: all).projectOf == ["Socks": "Trip"])
    }

    @Test func withoutTheSwitchEverySubtaskIsUp() {
        let plain = [makeTask("Trip"), step("Book", of: "Trip", order: 0), step("Pack", of: "Trip", order: 1)]
        #expect(TaskSteps.plan(in: plain) == TaskSteps.Plan())
    }

    @Test func thePoolShowsTheNextActionAloneUnderItsTasksName() {
        let today = TaskDue(day: LocalDate(TestCalendar.wednesday))
        let dated = tasks.map { task in
            var task = task
            task.due = today
            return task
        }
        let plan = DayScenario(tasks: dated).build(at: TestCalendar.context(TestCalendar.wednesday, "08:00"))
        #expect(plan.poolNames == ["Socks"])
        #expect(plan.pool.first?.project == "Trip")
    }

    @Test func aDoneStepBringsTheNextOneUpTomorrow() throws {
        var all = tasks
        all[2].status = .done
        let tomorrow = LocalDate("2026-10-22")
        let next = try #require(TaskSteps.afterDone(all[2], in: all, tomorrow: tomorrow))
        #expect(next.name == "Charger" && next.edits == [.due(TaskDue(day: tomorrow))])
    }

    @Test func theSwitchIsInTheLine() {
        let format = TestConfig.decode(TaskFileFormat.self, TaskFileFormat.fileName)
        let entry = TaskEntry(line: "- [ ] Trip 🪜", format: format)
        #expect(entry?.stepsOneByOne == true && entry?.name == "Trip")
        #expect(entry?.line(format: format) == "- [ ] Trip 🪜")
    }
}
