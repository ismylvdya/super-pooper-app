import Foundation
import Testing
@testable import SuperPooperApp

/// One day's pool sections as data: the defaults, and renamed or deleted notes followed.
struct DaySectionsTests {
    private let wednesday = LocalDate(TestCalendar.wednesday)
    private var definitions: [PoolSectionDefinition] { TestConfig.rules.pool.defaultSections }

    @Test func aDayWithoutASnapshotHasTheThreeDefaults() {
        let sections = DaySections.defaults(on: wednesday, definitions: definitions)
        #expect(sections.order.map(\.id) == ["morning", "day", "evening"])
        #expect(sections.order.allSatisfy { !$0.isCustom && $0.title == nil })
        #expect(sections.membership.isEmpty && sections.worms.isEmpty)
    }

    @Test func renamingFollowsMembershipAndWorms() {
        var sections = DaySections.defaults(on: wednesday, definitions: definitions)
        sections.membership = ["Стирка 🧺": "day", "Купить молоко": "evening"]
        sections.worms = [DayWorm(id: "w", members: ["Стирка 🧺", "Позвонить в банк"])]
        let renamed = sections.renaming(from: "Стирка 🧺", to: "Большая стирка")
        #expect(renamed.membership == ["Большая стирка": "day", "Купить молоко": "evening"])
        #expect(renamed.worms.map(\.members) == [["Большая стирка", "Позвонить в банк"]])
        #expect(renamed.section(of: "Большая стирка") == "day" && renamed.section(of: "Стирка 🧺") == nil)
    }

    @Test func removingLeavesNoMemberAndAWormOfOneGoes() {
        var sections = DaySections.defaults(on: wednesday, definitions: definitions)
        sections.membership = ["A": "evening", "B": "day"]
        sections.worms = [DayWorm(id: "w1", members: ["A", "C"]), DayWorm(id: "w2", members: ["B", "C", "D"])]
        let removed = sections.removing(["A", "C"])
        #expect(removed.membership == ["B": "day"])
        #expect(removed.worms == [DayWorm(id: "w2", members: ["B", "D"])])
    }
}
