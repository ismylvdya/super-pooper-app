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

    @Test func aTaskDroppedOnSomedayGetsThatStatus() async throws {
        let model = try model()
        await model.relocateTask("Pay the internet", to: .list(try list("someday", model), order: []), fromScheduled: false, slot: nil)
        #expect(model.task(named: "Pay the internet")?.status == .someday)
        let plan = model.plan(at: model.clock.now)
        #expect(model.backlogTasks(try list("someday", model), plan: plan).map(\.name) == ["Pay the internet", "Read a novel"])
    }

    @Test func aSomedayTaskDroppedInTodaysPoolIsThisWeekAtThatSpot() async throws {
        let model = try model()
        await model.relocateTask("Read a novel", to: .pool(day: context.today, section: nil, order: ["Pay the internet", "Read a novel"]),
                                 fromScheduled: false, slot: nil)
        let note = try #require(model.task(named: "Read a novel"))
        #expect(note.status == .thisWeek && note.due == nil && note.isInTodayPool)
        #expect(model.plan(at: model.clock.now).pool.map(\.id).firstIndex(of: "Read a novel") == 1)
        #expect(model.plan(at: model.clock.now).pool.contains { $0.id == "Read a novel" })
    }

    @Test func aTaskDroppedInAnotherDaysPoolIsDatedThatDay() async throws {
        let model = try model()
        let friday = context.today.adding(days: 2)
        await model.relocateTask("Paint the door", to: .pool(day: friday, section: nil, order: []), fromScheduled: false, slot: nil)
        let note = try #require(model.task(named: "Paint the door"))
        #expect(note.status == .thisWeek && note.due == TaskDue(day: friday))
        #expect(model.plan(at: model.clock.now, dayOffset: 2).pool.contains { $0.id == "Paint the door" })
    }

    /// A Someday task dropped on Soon on today's page stays there: this week's, kept out of today until tomorrow.
    @Test func aSomedayTaskDroppedOnSoonWaitsInSoon() async throws {
        let model = try model()
        let soon = try list("thisWeek", model)
        await model.relocateTask("Read a novel", to: .list(soon, order: []), fromScheduled: false, slot: nil)
        #expect(model.task(named: "Read a novel")?.status == .thisWeek)
        #expect(model.backlogTasks(soon, plan: model.plan(at: model.clock.now)).map(\.name) == ["Read a novel"])
    }

    @Test func aBacklogTaskDroppedOnTheTimelineGetsThatTime() async throws {
        let model = try model()
        let moment = context.date(context.today, LocalTime("15:00"))
        await model.relocateTask("Paint the door", to: .scheduled(moment), fromScheduled: false, slot: nil)
        let note = try #require(model.task(named: "Paint the door"))
        #expect(note.status == .thisWeek && note.due == TaskDue(day: context.today, time: LocalTime("15:00")))
    }

    @Test func eachPlanningListCanSendATaskThroughThePoolAndCalendarAndReceiveItBack() async throws {
        let moment = context.date(context.today, LocalTime("15:00"))
        for task in tasks {
            let model = try model()
            let lists = model.backlogLists
            let source = try #require(lists.first { $0.status == task.status })
            let section = try #require(model.config.rules.pool.defaultSections.first { $0.routine == .evening })
            let rows = [task.name]
            for destination in lists where destination != source {
                await model.relocateTask(task.name, to: .list(source, order: rows), fromScheduled: false, slot: nil)
                await model.relocateTask(task.name, to: .list(destination, order: rows), fromScheduled: false, slot: nil)
                #expect(model.task(named: task.name)?.status == destination.status)
            }

            await model.relocateTask(task.name, to: .list(source, order: rows), fromScheduled: false, slot: nil)
            await model.relocateTask(task.name, to: .scheduled(moment), fromScheduled: false, slot: nil)
            #expect(model.task(named: task.name)?.due == TaskDue(day: context.today, time: LocalTime("15:00")))
            await model.relocateTask(task.name, to: .list(source, order: rows), fromScheduled: true, slot: LocalTime("15:00"))
            await model.relocateTask(task.name, to: .pool(day: context.today, section: section.id, order: [task.name]), fromScheduled: false, slot: nil)
            var note = try #require(model.task(named: task.name))
            #expect(note.status == .thisWeek && note.isInTodayPool && note.poolSection == section.id)
            #expect(model.plan(at: model.clock.now).sections.first { $0.id == section.id }?.items.contains { $0.id == task.name } == true)

            await model.relocateTask(task.name, to: .scheduled(moment), fromScheduled: false, slot: nil)
            note = try #require(model.task(named: task.name))
            #expect(note.due == TaskDue(day: context.today, time: LocalTime("15:00")))
            #expect(!note.isInTodayPool && note.poolSection == nil)

            await model.relocateTask(task.name, to: .pool(day: context.today, section: section.id, order: [task.name]),
                                     fromScheduled: true, slot: LocalTime("15:00"))
            note = try #require(model.task(named: task.name))
            #expect(note.due == nil && note.isInTodayPool && note.poolSection == section.id)

            for destination in lists {
                await model.relocateTask(task.name, to: .scheduled(moment), fromScheduled: false, slot: nil)
                await model.relocateTask(task.name, to: .list(destination, order: [task.name]), fromScheduled: true, slot: LocalTime("15:00"))
                note = try #require(model.task(named: task.name))
                #expect(note.status == destination.status && note.due == nil && !note.isInTodayPool && note.poolSection == nil)
                #expect(model.backlogTasks(destination, plan: model.plan(at: model.clock.now)).contains { $0.name == task.name })
            }
        }
    }
}
