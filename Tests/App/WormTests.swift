import Foundation
import Testing
@testable import SuperPooperApp

/// Worm: the selected tasks share one plate for the shown day, purely in the app; Unworm takes it apart.
@MainActor
struct WormTests {
    private func makeModel(_ tasks: [TaskItem]) throws -> (AppModel, TaskStore) {
        let model = try #require(PreviewModel.make(tasks: tasks, delay: NoDelay())).model
        return (model, model.parts.services.tasks)
    }

    private var tasks: [TaskItem] {
        [makeTask("Купить молоко"), makeTask("Позвонить в банк"), makeTask("Отчёт"),
         makeHabit("Чтение 📖", status: .habit) { $0.habit.timeOfDay = .evening }]
    }

    private func sections(_ model: AppModel) -> [String: [String]] {
        Dictionary(model.plan(at: model.clock.now).sections.map { ($0.id, $0.items.map(\.id)) }, uniquingKeysWith: { first, _ in first })
    }

    @Test func wormedTasksStandTogetherInTheFirstOnesSection() async throws {
        let (model, _) = try makeModel(tasks)
        let today = model.context().today
        let first = try #require(model.plan(at: model.clock.now).poolNames.first { $0 != "Чтение 📖" })
        model.worm([first, "Чтение 📖"], on: today)
        let plan = model.plan(at: model.clock.now)
        let day = try #require(sections(model)["day"])
        let index = try #require(day.firstIndex(of: first))
        #expect(day[index + 1] == "Чтение 📖", "the evening habit stands right after the first member, in its section")
        #expect(sections(model)["evening"] == nil, "an empty section goes")
        #expect(PoolSegments.make(plan.pool, worms: plan.worms).contains { $0.items.map(\.id) == [first, "Чтение 📖"] })
    }

    /// Decision: a member done today stays in its worm (out of the pool, as every done task) and is back on the plate
    /// once unmarked.
    @Test func aDoneMemberStaysInItsWorm() async throws {
        let (model, _) = try makeModel(tasks)
        let today = model.context().today
        model.worm(["Купить молоко", "Позвонить в банк", "Отчёт"], on: today)
        await model.setHabitMark("Чтение 📖", on: today, to: .done)
        await model.perform(.done, on: "Позвонить в банк")
        #expect(model.sections(on: today).worm(of: "Позвонить в банк")?.members.count == 3)
        let plan = model.plan(at: model.clock.now)
        #expect(PoolSegments.make(plan.pool, worms: plan.worms).first { $0.wormID != nil }?.items.map(\.id).sorted()
                == ["Купить молоко", "Отчёт"].sorted())
    }

    @Test func unwormingOneOfTwoEndsTheWorm() async throws {
        let (model, _) = try makeModel(tasks)
        let today = model.context().today
        model.worm(["Купить молоко", "Позвонить в банк"], on: today)
        model.worm(["Купить молоко", "Отчёт"], on: today)
        #expect(model.sections(on: today).worms.count == 1, "a task joins the worm it is wormed with")
        #expect(model.sections(on: today).worms.first?.members.count == 3)
        model.unworm(["Отчёт"], on: today)
        #expect(model.sections(on: today).worms.first?.members == ["Купить молоко", "Позвонить в банк"])
        await model.perform(.unworm, on: "Позвонить в банк")
        #expect(model.sections(on: today).worms.isEmpty)
    }

    @Test func nothingIsWrittenToNotes() async throws {
        let (model, store) = try makeModel(tasks)
        let today = model.context().today
        let before = try await store.load().tasks
        model.worm(["Купить молоко", "Позвонить в банк"], on: today)
        model.unworm(["Купить молоко"], on: today)
        #expect(try await store.load().tasks == before)
        #expect(model.tasks.sorted { $0.name < $1.name } == before.sorted { $0.name < $1.name })
    }

    /// A worm dragged whole: the other members follow the grabbed one into the section it is dropped in.
    @Test func aWormDraggedWholeMovesEveryMember() async throws {
        let (model, _) = try makeModel(tasks)
        let today = model.context().today
        model.worm(["Купить молоко", "Позвонить в банк"], on: today)
        let order = PoolDropOrder.keepingTogether(["Позвонить в банк", "Отчёт", "Купить молоко"], dragged: "Купить молоко",
                                                  along: ["Купить молоко", "Позвонить в банк"])
        #expect(order == ["Отчёт", "Купить молоко", "Позвонить в банк"])
        model.moveTasks(["Купить молоко", "Позвонить в банк"], toSection: "evening", poolOrder: order, on: today)
        let evening = try #require(sections(model)["evening"])
        let milk = try #require(evening.firstIndex(of: "Купить молоко"))
        #expect(evening.indices.contains(milk + 1) && evening[milk + 1] == "Позвонить в банк")
    }
}
