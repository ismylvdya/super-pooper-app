import Foundation
import Testing
@testable import SuperPooperApp

/// Deleting or completing a parent through the app's intents takes its subtasks along (.1965); the delete confirmation
/// says how many; reopening the parent brings none back.
@MainActor
struct SubtaskCascadeAppTests {
    private func subtask(_ name: String, of parents: String..., status: TaskStatus = .thisWeek) -> TaskItem {
        makeTask(name, status: status) { $0.projects = parents }
    }

    /// "Renovation" → "Paint" → "Buy paint"; "Buy boxes" also belongs to "Move", which stays open.
    private var family: [TaskItem] {
        [makeTask("Renovation"), subtask("Paint", of: "Renovation"), subtask("Buy paint", of: "Paint"),
         makeTask("Move"), subtask("Buy boxes", of: "Renovation", "Move")]
    }

    private func names(_ model: AppModel) -> Set<String> { Set(model.tasks.map(\.name)) }

    @Test func deletingAParentDeletesItsSubtasksAllTheWayDown() async throws {
        let model = try #require(PreviewModel.make(tasks: family, delay: NoDelay())).model
        await model.perform(.delete, on: "Renovation")
        #expect(names(model) == ["Move", "Buy boxes"])
    }

    @Test func completingAParentCompletesItsSubtasksAllTheWayDown() async throws {
        let model = try #require(PreviewModel.make(tasks: family, delay: NoDelay())).model
        await model.perform(.done, on: "Renovation")
        // Done tasks are filed away at once.
        #expect(names(model) == ["Move", "Buy boxes"])
        let filed = Dictionary(uniqueKeysWithValues: model.filedTasks.map { ($0.name, $0) })
        #expect(Set(filed.keys) == ["Renovation", "Paint", "Buy paint"])
        #expect(filed.values.allSatisfy { $0.status == .done && $0.completedDate == model.context().today })
    }

    /// Done from the task page's status picker goes through the same writer.
    @Test func aStatusOfDoneTakesTheSubtasksAlongToo() async throws {
        let model = try #require(PreviewModel.make(tasks: family, delay: NoDelay())).model
        await model.setStatus(.done, of: "Paint")
        #expect(Set(model.filedTasks.map(\.name)) == ["Paint", "Buy paint"])
        #expect(model.task(named: "Renovation")?.status == .thisWeek)
    }

    @Test func reopeningTheParentBringsNoSubtaskBack() async throws {
        let done = [makeTask("Trip", status: .done) { $0.completedDate = LocalDate("2026-10-20") },
                    subtask("Pack", of: "Trip", status: .done)]
        let model = try #require(PreviewModel.make(tasks: done, delay: NoDelay())).model
        await model.moveToThisWeek("Trip")
        #expect(model.task(named: "Trip")?.status == .thisWeek)
        #expect(model.task(named: "Pack")?.status == .done)
    }

    @Test func theDeleteConfirmationSaysHowManySubtasksGoAlong() throws {
        let model = try #require(PreviewModel.make(tasks: family)).model
        #expect(model.subtasksGoingAlong(with: "Renovation", action: .delete) == 2)
        #expect(model.subtasksGoingAlong(with: "Paint", action: .delete) == 1)
        #expect(model.subtasksGoingAlong(with: "Move", action: .delete) == 0)
        #expect(model.subtasksGoingAlong(with: "Renovation", action: .archive) == 0)

        let delete = TestConfig.actions.definition(.delete)
        let message = L10n.format("confirm.delete.message", "Renovation")
        #expect(ConfirmationText.message(PendingAction(action: delete, taskName: "Renovation", kind: .task, subtasks: 2))
                == message + "\n\n2 subtasks go with it.")
        #expect(ConfirmationText.message(PendingAction(action: delete, taskName: "Paint", kind: .task, subtasks: 1))
                == L10n.format("confirm.delete.message", "Paint") + "\n\n1 subtask goes with it.")
        #expect(ConfirmationText.message(PendingAction(action: delete, taskName: "Move", kind: .task, subtasks: 0))
                == L10n.format("confirm.delete.message", "Move"))
    }
}
