import Foundation
import Testing
@testable import SuperPooperApp

/// Select mode: one action for all the selected tasks, one Undo in the banner for all of them.
@MainActor
struct BatchActionTests {
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

    @Test func highPriorityTurnsOnForAllUnlessAllAreHigh() async throws {
        let (model, events) = try makeModel([makeTask("Milk"), makeTask("Bank") { $0.isHighPriority = true }])
        await model.performOfferingUndo(action(model, .highPriority), on: ["Milk", "Bank"], day: nil)
        #expect(model.task(named: "Milk")?.isHighPriority == true)
        #expect(model.task(named: "Bank")?.isHighPriority == true, "one already high stays high")
        await model.performOfferingUndo(action(model, .highPriority), on: ["Milk", "Bank"], day: nil)
        #expect(model.task(named: "Milk")?.isHighPriority == false && model.task(named: "Bank")?.isHighPriority == false)

        await model.undo(try offer(events).id)
        #expect(model.task(named: "Milk")?.isHighPriority == true && model.task(named: "Bank")?.isHighPriority == true)
        #expect(BatchEdits.highPriority(for: [makeTask("A") { $0.isHighPriority = true }, makeTask("B")]))
        #expect(!BatchEdits.highPriority(for: [makeTask("A") { $0.isHighPriority = true }]))
    }

    @Test func deleteTakesEverySelectedNote() async throws {
        let (model, events) = try makeModel([makeTask("Milk"), makeTask("Bank"), makeTask("Paint"),
                                             makeTask("Buy paint") { $0.projects = ["Paint"] }])
        await model.performOfferingUndo(action(model, .delete), on: ["Milk", "Paint", "Buy paint"], day: nil)
        #expect(model.tasks.map(\.name) == ["Bank"])
        let offer = try offer(events)
        #expect(events.sent.count == 1, "one banner for all of them")
        #expect(offer.names == ["Milk", "Paint", "Buy paint"] && offer.along.isEmpty)

        await model.undo(offer.id)
        #expect(Set(model.tasks.map(\.name)) == ["Milk", "Bank", "Paint", "Buy paint"])
        #expect(model.task(named: "Buy paint")?.projects == ["Paint"])
    }

    @Test func doneMarksEachAndOneUndoReopensThemAll() async throws {
        let (model, events) = try makeModel([makeTask("Milk"), makeTask("Bank")])
        await model.performOfferingUndo(action(model, .done), on: ["Milk", "Bank"], day: nil)
        #expect(model.task(named: "Milk") == nil && model.task(named: "Bank") == nil, "done tasks are filed away")
        await model.undo(try offer(events).id)
        #expect(model.task(named: "Milk")?.status == .thisWeek && model.task(named: "Bank")?.status == .thisWeek)
    }

    /// The selection bar for two pool tasks: Done and Delete as buttons, Worm among the rest; Worm takes them in the
    /// pool's order.
    @Test func theSelectionBarOffersWormAndWormsInThePoolsOrder() async throws {
        let (model, _) = try makeModel([makeTask("Milk"), makeTask("Bank")])
        let today = model.context().today
        let entries = model.selectionEntries(for: ["Milk", "Bank"], on: today)
        #expect(entries.frequent.map(\.id) == [.done, .notToday])
        #expect(entries.more.map(\.id).contains(.delete))
        #expect(entries.more.map(\.id).contains(.worm) && !entries.more.map(\.id).contains(.unworm))
        await model.perform(action(model, .worm), onSelected: ["Milk", "Bank"], on: today)
        let order = model.plan(at: model.clock.now).poolNames
        #expect(model.sections(on: today).worms.first?.members == order)
        #expect(model.selectionEntries(for: ["Milk"], on: today).more.map(\.id).contains(.unworm))
    }
}
