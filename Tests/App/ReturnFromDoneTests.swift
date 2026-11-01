import Foundation
import Testing
@testable import SuperPooperApp

/// Return in the Done list (its menu and a swipe to the right): a done task goes back to Soon, reopened — from the done
/// folder too, by the filed task itself, not its name. A filed task can also be deleted.
@MainActor
struct ReturnFromDoneTests {
    private func makeModel(_ tasks: [TaskItem]? = nil) throws -> (AppModel, RecordingEvents) {
        let events = RecordingEvents()
        let model = try #require(tasks.map { PreviewModel.make(tasks: $0, appEvents: events) } ?? PreviewModel.make(appEvents: events)).model
        return (model, events)
    }

    @Test func aFiledTaskComesBackToSoonReopened() async throws {
        let (model, events) = try makeModel()
        await model.perform(.done, on: "Позвонить в банк")
        await model.openList("done")
        let filed = try #require(model.filedTasks.first { $0.name == "Позвонить в банк" })
        #expect(model.task(named: "Позвонить в банк") == nil)

        await model.perform(.returnFromDone, onFiled: filed.id)

        let back = try #require(model.task(named: "Позвонить в банк"))
        #expect(back.status == .thisWeek && back.completedDate == nil)
        #expect(!model.filedTasks.contains { $0.id == filed.id })
        #expect(events.sent.last == .returned("Позвонить в банк"))
        await model.openList("done")
        #expect(!model.listContents("done", query: "").filed.contains { $0.name == "Позвонить в банк" })
    }

    /// A filed task whose name an active task has taken: Return and Delete act on the filed one, never the active one.
    @Test func aFiledTaskIsNotMistakenForAnActiveOneOfTheSameName() async throws {
        let (model, events) = try makeModel()
        await model.perform(.done, on: "Позвонить в банк")
        await model.openList("done")
        let filed = try #require(model.filedTasks.first { $0.name == "Позвонить в банк" })
        _ = await model.create(.newTask, named: "Позвонить в банк")
        let active = try #require(model.task(named: "Позвонить в банк"))

        await model.perform(.delete, onFiled: filed.id)

        #expect(model.task(named: "Позвонить в банк") == active)
        #expect(!model.filedTasks.contains { $0.id == filed.id })
        #expect(events.sent.last == .deleted("Позвонить в банк"))
    }

    /// A done task still among the active ones (not filed yet) is reopened in place.
    @Test func aDoneTaskInTheTasksFolderIsReopened() async throws {
        var task = TaskItem(id: TaskID("TaskNotes/Tasks/Report.md"), name: "Report", status: .done)
        task.completedDate = LocalDate("2026-10-20")
        let (model, events) = try makeModel([task])
        await model.perform(.returnFromDone, on: "Report")
        let back = try #require(model.task(named: "Report"))
        #expect(back.status == .thisWeek && back.completedDate == nil)
        #expect(events.sent.last == .returned("Report"))
    }

    /// The swipes a row offers come from actions.json through the model: Done for an open task, Return for a done one.
    @Test func theModelOffersTheRowsSwipes() throws {
        let (model, _) = try makeModel()
        let open = try #require(model.task(named: "Позвонить в банк"))
        #expect(model.swipeActions(.task, for: DayItem(listed: open), isToday: false).leading.map(\.id) == [.done])
        var done = open
        done.status = .done
        #expect(model.swipeActions(.task, for: DayItem(listed: done), isToday: false).leading.map(\.id) == [.returnFromDone])
        #expect(model.swipeActions(.task, for: DayItem(listed: done), isToday: false).trailing.map(\.id) == [.delete])
    }

    /// Back to today, from the bottom of Soon (a swipe to the right on a task put off with Not today).
    @Test func backToTodayBringsAPostponedTaskBack() async throws {
        let (model, _) = try makeModel()
        await model.perform(.notToday, on: "Позвонить в банк")
        #expect(model.postponedTasks.contains { $0.name == "Позвонить в банк" })
        await model.perform(.backToToday, on: "Позвонить в банк")
        #expect(!model.postponedTasks.contains { $0.name == "Позвонить в банк" })
    }
}
