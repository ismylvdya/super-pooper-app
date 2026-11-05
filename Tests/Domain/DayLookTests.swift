import Testing
@testable import SuperPooperApp

/// Today's look in the file and the app's sections.
struct DayLookTests {
    private let day = LocalDate("2026-10-21")
    private let definitions = [PoolSectionDefinition(id: "morning", title: "Morning"), PoolSectionDefinition(id: "day", title: "Day", catchesRest: true)]

    private func look(_ sections: [(String, [String])], kept: [String] = []) -> DayLook {
        DayLook(sections: sections.map { .init(title: $0.0, names: $0.1) })
    }

    @Test func applyingKeepsKnownSectionsAndMakesNewOnes() {
        let sections = DaySections.defaults(on: day, definitions: definitions)
        let applied = sections.applying(look([("Day", ["A"]), ("Night", ["B"]), ("Morning", ["C"])]), title: { section in
            section.title ?? section.id.capitalized
        }, makeID: { "new" })
        #expect(applied.order.map(\.id) == ["day", "new", "morning"])
        #expect(applied.order[1].title == "Night" && applied.order[1].isCustom)
        #expect(applied.section(of: "a") == "day" && applied.section(of: "B") == "new" && applied.section(of: "C") == "morning")
    }

    @Test func aSectionTheLookDoesNotNameStaysBehind() {
        let sections = DaySections.defaults(on: day, definitions: definitions)
        let applied = sections.applying(look([("Day", ["A"])]), title: { $0.title ?? $0.id.capitalized }, makeID: { "new" })
        #expect(applied.order.map(\.id) == ["day", "morning"])
    }
}
