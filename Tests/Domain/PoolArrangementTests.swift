import Foundation
import Testing
@testable import SuperPooperApp

/// The pool split into the day's sections: routines in Morning and Evening, the rest in Day, the user's moves for that
/// day only.
struct PoolArrangementTests {
    private let wednesday = LocalDate(TestCalendar.wednesday)
    private var thursday: LocalDate { wednesday.adding(days: 1) }
    private var definitions: [PoolSectionDefinition] { TestConfig.rules.pool.defaultSections }

    private func item(_ name: String, _ routine: HabitTimeOfDay? = nil, depth: Int = 0) -> DayItem {
        var item = DayItem(task: makeHabit(name, status: .habit) { $0.habit.timeOfDay = routine }, state: .open, blockers: [], problems: [])
        item.depth = depth
        return item
    }

    private var pool: [DayItem] {
        [item("Купить молоко"), item("Утро — душ 🚿", .morning), item("Позвонить в банк"), item("Стирка 🧺", .evening)]
    }

    private func arrange(_ sections: DaySections, _ pool: [DayItem]? = nil) -> [PoolSectionContent] {
        PoolArrangement.arrange(pool ?? self.pool, sections: sections, definitions: definitions)
    }

    @Test func byDefaultRoutinesGoToMorningAndEveningTheRestToDay() {
        let content = arrange(.defaults(on: wednesday, definitions: definitions))
        #expect(content.map(\.id) == ["morning", "day", "evening"])
        #expect(content.map(\.title) == ["section.morning", "section.day", "section.evening"])
        #expect(content[0].items.map(\.id) == ["Утро — душ 🚿"])
        #expect(content[1].items.map(\.id) == ["Купить молоко", "Позвонить в банк"])
        #expect(content[2].items.map(\.id) == ["Стирка 🧺"])
    }

    @Test func anEmptySectionGoesWhateverItIs() {
        var sections = DaySections.defaults(on: wednesday, definitions: definitions)
        sections.order.insert(DaySection(id: "errands", title: "Errands", isCustom: true), at: 1)
        let content = arrange(sections, [item("Купить молоко")])
        #expect(content.map(\.id) == ["day"])
    }

    @Test func aCustomSectionShowsItsTitleWhereItStands() {
        var sections = DaySections.defaults(on: wednesday, definitions: definitions)
        sections.order.insert(DaySection(id: "errands", title: "Errands", isCustom: true), at: 1)
        sections.membership = ["Позвонить в банк": "errands"]
        let content = arrange(sections)
        #expect(content.map(\.id) == ["morning", "errands", "day", "evening"])
        #expect(content[1].title == "Errands" && content[1].isCustom)
        #expect(content[1].items.map(\.id) == ["Позвонить в банк"])
    }

    @Test func theSnapshotOverridesTheRoutineForThatDayOnly() {
        var sections = DaySections.defaults(on: wednesday, definitions: definitions)
        sections.membership["Стирка 🧺"] = "day"
        #expect(arrange(sections)[1].items.map(\.id) == ["Купить молоко", "Позвонить в банк", "Стирка 🧺"])
        #expect(arrange(.defaults(on: thursday, definitions: definitions))[2].items.map(\.id) == ["Стирка 🧺"])
    }

    @Test func withinASectionThePoolOrderIsKept() {
        let reversed = Array(pool.reversed())
        #expect(arrange(.defaults(on: wednesday, definitions: definitions), reversed)[1].items.map(\.id) == ["Позвонить в банк", "Купить молоко"])
    }

    /// Own sections live in their day: an open task of yesterday's own section is in Day today.
    @Test func theNextDayStartsFromTheDefaultsAndCustomMembersFallIntoDay() {
        var thursdaySections = DaySections.defaults(on: thursday, definitions: definitions)
        thursdaySections.membership["Купить молоко"] = "errands"
        let content = arrange(thursdaySections)
        #expect(content.map(\.id) == ["morning", "day", "evening"])
        #expect(content[1].items.map(\.id) == ["Купить молоко", "Позвонить в банк"])
    }

    @Test func aSubtaskStaysWithItsParent() {
        var sections = DaySections.defaults(on: wednesday, definitions: definitions)
        sections.membership["Шаг"] = "evening"
        let content = arrange(sections, [item("Утро — душ 🚿", .morning), item("Шаг", depth: 1), item("Купить молоко")])
        #expect(content[0].items.map(\.id) == ["Утро — душ 🚿", "Шаг"])
    }

    /// The day's pool is its sections one after another: the morning routine on top, the evening one at the bottom.
    @Test func thePlanPoolIsTheSectionsInOrder() {
        let tasks = [makeTask("High") { $0.isHighPriority = true }, makeHabit("Evening", status: .habit) { $0.habit.timeOfDay = .evening },
                     makeHabit("Morning", status: .habit) { $0.habit.timeOfDay = .morning }]
        let plan = DayScenario(tasks: tasks).build()
        #expect(plan.poolNames == ["Morning", "High", "Evening"])
        #expect(plan.sections.map { $0.items.map(\.id) } == [["Morning"], ["High"], ["Evening"]])
    }
}
