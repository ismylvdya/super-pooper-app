import Foundation
import Testing
@testable import SuperPooperApp

/// Undo in the banner instead of the delete confirmation (.27143): an action that can be taken back happens at once, the
/// banner offers Undo, and Undo puts back exactly what was — out of the trash, out of the done folder, subtasks and the
/// tasks waiting for them too, today's decisions. Only the latest offer works.
@MainActor
struct UndoTests {
    private func makeModel(_ tasks: [TaskItem]) throws -> (AppModel, RecordingEvents) {
        let events = RecordingEvents()
        let model = try #require(PreviewModel.make(tasks: tasks, delay: NoDelay(), appEvents: events)).model
        return (model, events)
    }

    private func action(_ model: AppModel, _ id: ActionID) -> ActionDefinition { model.config.actions.definition(id) }

    private func offer(_ events: RecordingEvents) throws -> UndoOffer {
        guard case .undoable(let offer) = try #require(events.sent.last) else {
            Issue.record("the last banner offers Undo: \(events.sent)")
            throw CancellationError()
        }
        return offer
    }

    private var family: [TaskItem] {
        [makeTask("Renovation"), makeTask("Paint") { $0.projects = ["Renovation"] },
         makeTask("Buy paint") { $0.projects = ["Paint"] }]
    }

    @Test func deletingAsksNothingAndUndoBringsTheSubtasksBackFromTheTrash() async throws {
        let (model, events) = try makeModel(family)
        let delete = action(model, .delete)
        #expect(delete.needsConfirmation, "the dialog is still configured")
        #expect(!model.needsConfirmation(delete), "with a trash Delete happens at once")
        let before = model.tasks.sorted { $0.name < $1.name }
        await model.performOfferingUndo(delete, on: "Renovation")
        #expect(model.task(named: "Renovation") == nil && model.task(named: "Buy paint") == nil)
        let offer = try offer(events)
        #expect(offer.action == .delete && offer.name == "Renovation")
        #expect(offer.along == ["Paint", "Buy paint"], "the banner names the subtasks that went along")

        await model.undo(offer.id)

        #expect(model.tasks.sorted { $0.name < $1.name }.map(\.name) == before.map(\.name))
        #expect(model.task(named: "Buy paint")?.projects == ["Paint"])
        #expect(try await model.parts.services.trash?.notes().isEmpty == true)
    }

    /// The Done list: Delete asks nothing, the banner offers Undo, and Undo puts the task back into the done folder as it was.
    @Test func deletingAFiledTaskOffersUndoBackIntoTheDoneFolder() async throws {
        let (model, events) = try makeModel([makeTask("Report")])
        await model.performOfferingUndo(action(model, .done), on: "Report")
        let filed = try #require(model.filedTasks.first { $0.name == "Report" })
        await model.performOfferingUndo(action(model, .delete), onFiled: filed.id)
        #expect(model.filedTasks.isEmpty)
        let offer = try offer(events)
        #expect(offer.action == .delete && offer.name == "Report")

        await model.undo(offer.id)

        let back = try #require(model.filedTasks.first { $0.name == "Report" })
        #expect(back.status == filed.status && back.completedDate == filed.completedDate)
        #expect(model.task(named: "Report") == nil, "it stays in the done folder, not among the active tasks")
        #expect(try await model.parts.services.trash?.notes().isEmpty == true)
    }

    @Test func undoingArchiveRestoresTheStatus() async throws {
        let (model, events) = try makeModel([makeTask("Report", status: .halfYear)])
        await model.performOfferingUndo(action(model, .archive), on: "Report")
        #expect(model.task(named: "Report")?.status == .archived)
        await model.undo(try offer(events).id)
        #expect(model.task(named: "Report")?.status == .halfYear)
    }

    @Test func undoingAHabitsMarkClearsIt() async throws {
        let (model, events) = try makeModel([makeHabit("Water")])
        await model.performOfferingUndo(action(model, .done), on: "Water")
        let today = model.context().today
        #expect(model.task(named: "Water")?.mark(on: today) == .done)
        await model.undo(try offer(events).id)
        #expect(model.task(named: "Water")?.mark(on: today) == nil)
    }

    /// Only the latest offer takes its action back; an offer is used once.
    @Test func anOlderOfferDoesNothing() async throws {
        let (model, events) = try makeModel([makeTask("Report", status: .halfYear), makeTask("Notes", status: .halfYear)])
        await model.performOfferingUndo(action(model, .archive), on: "Report")
        let first = try offer(events)
        await model.performOfferingUndo(action(model, .archive), on: "Notes")
        let second = try offer(events)
        await model.undo(first.id)
        #expect(model.task(named: "Report")?.status == .archived)
        await model.undo(second.id)
        await model.undo(second.id)
        #expect(model.task(named: "Notes")?.status == .halfYear)
    }

    /// Opening a note is no change: nothing to take back, no banner.
    @Test func anActionThatCannotBeTakenBackOffersNothing() async throws {
        let (model, events) = try makeModel([makeTask("Report")])
        #expect(action(model, .open).undo == nil)
        #expect(action(model, .delete).undo == .trash)
        await model.performOfferingUndo(action(model, .returnFromDone), on: "Report")
        #expect(events.sent.isEmpty)
    }

    @Test func theBannerOffersUndoForTheConfiguredTime() {
        let offer = UndoOffer(id: UUID(), action: .delete, name: "Report", along: ["Draft"])
        let banner = BannerPresenter.banner(for: .undoable(offer))
        #expect(banner.undo == offer.id)
        #expect(banner.items == ["Draft"])
        #expect(banner.text == "Moved “Report” to trash.")
        #expect(TestConfig.rules.banners.undoSeconds == 5)
    }

    /// Review Focus 5: a batch delete takes the notes out of their section and worm; Undo brings both back.
    @Test func undoingABatchDeleteBringsBackSectionsAndWorms() async throws {
        let (model, events) = try makeModel([makeTask("Milk"), makeTask("Bank"), makeTask("Report")])
        let today = model.context().today
        model.parts.sections.update(on: today) { sections in
            sections.membership = ["Milk": "evening", "Bank": "evening"]
            sections.worms = [DayWorm(id: "w", members: ["Milk", "Bank"])]
        }
        await model.performOfferingUndo(action(model, .delete), on: ["Milk", "Bank"], day: nil)
        #expect(model.sections(on: today).worms.isEmpty && model.sections(on: today).membership.isEmpty)

        await model.undo(try offer(events).id)

        #expect(model.sections(on: today).worms == [DayWorm(id: "w", members: ["Milk", "Bank"])])
        #expect(model.sections(on: today).section(of: "Bank") == "evening")
        #expect(model.task(named: "Milk") != nil && model.task(named: "Bank") != nil)
    }
}
