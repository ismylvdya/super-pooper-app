import Testing
@testable import SuperPooperApp

/// A task's line names the pool's section it stands in (`#section_…`): a default section by its id, an own one by its title.
struct PoolSectionTagTests {
    private let day = LocalDate("2026-10-21")
    private let definitions = [PoolSectionDefinition(id: "morning", title: "Morning", routine: .morning),
                               PoolSectionDefinition(id: "day", title: "Day", catchesRest: true)]

    @Test func aTagIsTheIdOrTheTitleAsATagHasIt() {
        let sections = DaySections.defaults(on: day, definitions: definitions)
        #expect(PoolSectionTag.tag(of: sections.order[0], definitions: definitions) == "morning")
        #expect(PoolSectionTag.tag(of: DaySection(id: "x", title: "After work, tired", isCustom: true), definitions: definitions) == "after_work__tired")
        #expect(PoolSectionTag.title(ofTag: "after_work") == "After work")
    }

    @Test func anUnknownTagMakesAnOwnSectionOnce() {
        let sections = DaySections.defaults(on: day, definitions: definitions)
        let added = sections.addingTagged(["after_work", "morning"], definitions: definitions, makeID: { "new" })
        #expect(added.order.map(\.id) == ["morning", "day", "new"])
        #expect(added.order[2].title == "After work" && added.order[2].isCustom)
        #expect(added.addingTagged(["after_work"], definitions: definitions, makeID: { "other" }) == added)
    }

    /// The line's section places a task; one moved in the app that day goes first, the routine after.
    @Test func theLineSaysWhereATaskStands() {
        let sections = DaySections.defaults(on: day, definitions: definitions).addingTagged(["after_work"], definitions: definitions, makeID: { "own" })
        let tagged = makeTask("Tagged") { $0.poolSection = "after_work" }
        let morning = makeTask("Morning one") { $0.poolSection = "morning" }
        let plain = makeTask("Plain")
        let items = [tagged, morning, plain].map { DayItem(task: $0, state: .open, problems: []) }
        let arranged = PoolArrangement.arrange(items, sections: sections, definitions: definitions)
        #expect(arranged.map(\.id) == ["morning", "day", "own"])
        #expect(arranged.map { $0.items.map(\.id) } == [["Morning one"], ["Plain"], ["Tagged"]])
    }
}
