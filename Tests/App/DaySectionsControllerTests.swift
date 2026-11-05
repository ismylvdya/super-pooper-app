import Foundation
import Testing
@testable import SuperPooperApp

/// A task or a whole section moved in the pool stays so for that day; renamed notes keep their section, deleted ones
/// leave it, and Undo of the delete brings the membership back.
@MainActor
struct DaySectionsControllerTests {
    private func makeModel(_ tasks: [TaskItem]) throws -> (AppModel, RecordingEvents) {
        let events = RecordingEvents()
        let model = try #require(PreviewModel.make(tasks: tasks, delay: NoDelay(), appEvents: events)).model
        return (model, events)
    }

    private var tasks: [TaskItem] {
        [makeTask("Купить молоко"), makeTask("Позвонить в банк"),
         makeHabit("Чтение 📖", status: .habit) { $0.habit.timeOfDay = .evening }]
    }

    private func sectionItems(_ model: AppModel, at date: Date) -> [String: [String]] {
        Dictionary(model.plan(at: date).sections.map { ($0.id, $0.items.map(\.id)) }, uniquingKeysWith: { first, _ in first })
    }

    @Test func aTaskMovedToEveningIsThereOnlyThatDay() async throws {
        let (model, _) = try makeModel(tasks)
        let today = model.context().today
        let order = model.plan(at: model.clock.now).poolNames
        model.moveTask("Купить молоко", toSection: "evening", poolOrder: order, on: today)
        #expect(sectionItems(model, at: model.clock.now)["evening"]?.contains("Купить молоко") == true)
        #expect(model.sections(on: today.adding(days: 1)).section(of: "Купить молоко") == nil)
        #expect(model.sections(on: today).section(of: "Купить молоко") == "evening")
    }

    @Test func aRoutineMovedToDayDoesNotChangeTheRoutine() async throws {
        let (model, _) = try makeModel(tasks)
        model.updateSettings { $0.habits.eveningRoutine = ["Чтение 📖"] }
        let today = model.context().today
        model.moveTask("Чтение 📖", toSection: "day", poolOrder: model.plan(at: model.clock.now).poolNames, on: today)
        #expect(sectionItems(model, at: model.clock.now)["day"]?.contains("Чтение 📖") == true)
        #expect(model.settings.habits.eveningRoutine == ["Чтение 📖"])
        #expect(model.task(named: "Чтение 📖")?.habit.timeOfDay == .evening)
    }

    @Test func aSectionMovedKeepsItsMembers() async throws {
        let (model, _) = try makeModel(tasks)
        let today = model.context().today
        model.moveTask("Позвонить в банк", toSection: "morning", poolOrder: model.plan(at: model.clock.now).poolNames, on: today)
        model.moveSection("evening", order: ["evening", "morning", "day"], on: today)
        let plan = model.plan(at: model.clock.now)
        #expect(plan.sections.map(\.id) == ["evening", "morning", "day"])
        #expect(plan.sections[1].items.map(\.id) == ["Позвонить в банк"])
        #expect(plan.poolNames.first == "Чтение 📖")
    }

    /// Review Focus 5: a rename follows, a delete leaves no ghost member, Undo brings the membership back.
    @Test func aRenameFollowsAndADeleteLeaves() async throws {
        let (model, events) = try makeModel(tasks)
        let today = model.context().today
        let order = model.plan(at: model.clock.now).poolNames
        model.moveTask("Купить молоко", toSection: "evening", poolOrder: order, on: today)
        model.moveTask("Позвонить в банк", toSection: "morning", poolOrder: order, on: today.adding(days: 1))
        #expect(await model.rename("Купить молоко", to: "Купить кефир"))
        #expect(model.sections(on: today).section(of: "Купить кефир") == "evening")
        #expect(model.sections(on: today).membership["Купить молоко"] == nil)

        await model.performOfferingUndo(model.config.actions.definition(.delete), on: "Позвонить в банк")
        #expect(model.sections(on: today.adding(days: 1)).membership.isEmpty)
        guard case .undoable(let offer) = try #require(events.sent.last) else {
            Issue.record("the delete offers Undo")
            return
        }
        await model.undo(offer.id)
        #expect(model.sections(on: today.adding(days: 1)).section(of: "Позвонить в банк") == "morning")
    }

}
