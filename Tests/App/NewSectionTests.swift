import Foundation
import Testing
@testable import SuperPooperApp

/// Select → New section: a titled section of that day takes the selected tasks.
@MainActor
struct NewSectionTests {
    private func makeModel() throws -> AppModel {
        try #require(PreviewModel.make(tasks: [makeTask("Купить молоко"), makeTask("Позвонить в банк"), makeTask("Отчёт"),
                                              makeHabit("Чтение 📖", status: .habit) { $0.habit.timeOfDay = .evening }],
                                       delay: NoDelay())).model
    }

    private func sections(_ model: AppModel) -> [PoolSectionContent] { model.plan(at: model.clock.now).sections }

    @Test func aNewSectionTakesTheSelectedTasksAndStandsAfterTheFirstOnesSection() async throws {
        let model = try makeModel()
        let today = model.context().today
        let id = try #require(model.newSection(titled: "  Errands ", with: ["Купить молоко", "Позвонить в банк"], on: today))
        let shown = sections(model)
        #expect(shown.map(\.id).contains(id) && shown.map(\.id).last == "evening", "the section with tasks, the empty ones left out")
        let own = try #require(shown.first { $0.id == id })
        #expect(own.title == "Errands" && own.isCustom)
        #expect(Set(own.items.map(\.id)) == ["Купить молоко", "Позвонить в банк"])
        #expect(model.sections(on: today.adding(days: 1)).order.allSatisfy { !$0.isCustom }, "it lives in its day only")
    }

    @Test func aBlankTitleMakesNothing() async throws {
        let model = try makeModel()
        let today = model.context().today
        #expect(model.newSection(titled: "  ", with: ["Купить молоко"], on: today) == nil)
        #expect(model.sections(on: today).order.allSatisfy { !$0.isCustom })
    }

    @Test func itIsGoneWhenItsLastTaskLeaves() async throws {
        let model = try makeModel()
        let today = model.context().today
        let id = try #require(model.newSection(titled: "Errands", with: ["Отчёт"], on: today))
        model.moveTask("Отчёт", toSection: "day", poolOrder: model.plan(at: model.clock.now).poolNames, on: today)
        #expect(!sections(model).contains { $0.id == id })
    }

    /// A worm goes into the new section whole, or its first member would pull the others back.
    @Test func aWormMemberTakesItsWormAlong() async throws {
        let model = try makeModel()
        let today = model.context().today
        model.worm(["Купить молоко", "Позвонить в банк"], on: today)
        let id = try #require(model.newSection(titled: "Errands", with: ["Позвонить в банк"], on: today))
        #expect(Set(sections(model).first { $0.id == id }?.items.map(\.id) ?? []) == ["Купить молоко", "Позвонить в банк"])
    }
}
