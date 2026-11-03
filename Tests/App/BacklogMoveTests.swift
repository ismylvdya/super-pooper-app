import Foundation
import Testing
@testable import SuperPooperApp

/// Drags between the backlog pages, the pool and the timeline, through the app on in-memory notes.
@MainActor
struct BacklogMoveTests {
    private let context = PreviewSamples.context
    private let tasks = [
        TaskItem(id: TaskID("TaskNotes/Tasks/pay.md"), name: "Pay the internet", status: .thisWeek),
        TaskItem(id: TaskID("TaskNotes/Tasks/read.md"), name: "Read a novel", status: .someday),
        TaskItem(id: TaskID("TaskNotes/Tasks/paint.md"), name: "Paint the door", status: .halfYear),
    ]

    private func model() throws -> AppModel {
        try #require(PreviewModel.make(tasks: tasks)).model
    }

    private func list(_ id: String, _ model: AppModel) throws -> BacklogList {
        try #require(model.backlogLists.first { $0.id == id })
    }

    @Test func aPoolTaskDroppedOnSoonIsNotToday() async throws {
        let model = try model()
        #expect(model.plan(at: model.clock.now).pool.contains { $0.id == "Pay the internet" })
        await model.moveToBacklog("Pay the internet", list: try list("thisWeek", model), shown: context.today, fromShownDay: true)
        #expect(model.dayState.postponed == ["Pay the internet"])
        #expect(model.task(named: "Pay the internet")?.status == .thisWeek)
        let plan = model.plan(at: model.clock.now)
        #expect(!plan.pool.contains { $0.id == "Pay the internet" })
        #expect(model.backlogTasks(try list("thisWeek", model), plan: plan).map(\.name) == ["Pay the internet"])
    }

    @Test func aTaskDroppedOnSomedayGetsThatStatus() async throws {
        let model = try model()
        await model.moveToBacklog("Pay the internet", list: try list("someday", model), shown: context.today, fromShownDay: true)
        #expect(model.task(named: "Pay the internet")?.status == .someday)
        let plan = model.plan(at: model.clock.now)
        #expect(model.backlogTasks(try list("someday", model), plan: plan).map(\.name) == ["Pay the internet", "Read a novel"])
    }

    @Test func aSomedayTaskDroppedInTodaysPoolIsThisWeekAtThatSpot() async throws {
        let model = try model()
        await model.bringFromBacklog("Read a novel", to: context.today, poolOrder: ["Pay the internet", "Read a novel"])
        let note = try #require(model.task(named: "Read a novel"))
        #expect(note.status == .thisWeek && note.due == nil)
        #expect(model.dayState.manualOrder?.firstIndex(of: "Read a novel") == 1)
        #expect(model.plan(at: model.clock.now).pool.contains { $0.id == "Read a novel" })
    }

    @Test func aTaskDroppedInAnotherDaysPoolIsDatedThatDay() async throws {
        let model = try model()
        let friday = context.today.adding(days: 2)
        await model.bringFromBacklog("Paint the door", to: friday, poolOrder: nil)
        let note = try #require(model.task(named: "Paint the door"))
        #expect(note.status == .thisWeek && note.due == TaskDue(day: friday))
        #expect(model.dayState.manualOrder == nil, "another day's pool has no order of its own")
        #expect(model.plan(at: model.clock.now, dayOffset: 2).pool.contains { $0.id == "Paint the door" })
    }

    /// A Someday task dropped on Soon on today's page stays there: this week's, kept out of today until tomorrow.
    @Test func aSomedayTaskDroppedOnSoonWaitsInSoon() async throws {
        let model = try model()
        let soon = try list("thisWeek", model)
        await model.moveToBacklog("Read a novel", list: soon, shown: context.today, fromShownDay: false)
        #expect(model.task(named: "Read a novel")?.status == .thisWeek)
        #expect(model.backlogTasks(soon, plan: model.plan(at: model.clock.now)).map(\.name) == ["Read a novel"])
    }

    @Test func aBacklogTaskDroppedOnTheTimelineGetsThatTime() async throws {
        let model = try model()
        let moment = context.date(context.today, LocalTime("15:00"))
        await model.scheduleFromBacklog("Paint the door", at: moment)
        let note = try #require(model.task(named: "Paint the door"))
        #expect(note.status == .thisWeek && note.due == TaskDue(day: context.today, time: LocalTime("15:00")))
        #expect(!model.canBringFromBacklog("Nothing"))
    }
}
