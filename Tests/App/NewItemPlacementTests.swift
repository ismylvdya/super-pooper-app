import Foundation
import Testing
@testable import SuperPooperApp

/// Where a dragged "+" lands is the new item's: on a timeline its day and time (a habit's reminder time), in the pool
/// the spot between the rows and the section it was let go in.
@MainActor
struct NewItemPlacementTests {
    private let friday = LocalDate("2026-11-06")

    private func makeModel() throws -> AppModel {
        try #require(PreviewModel.make(tasks: [makeTask("A"), makeTask("B")], delay: NoDelay())).model
    }

    @Test func aTimelinePlacementPresetsTheDraftsDayAndTime() throws {
        let model = try makeModel()
        let page = model.newItemPage(NewItemSeed(kind: .task, placement: .timeline(day: friday, time: LocalTime("15:30"))))
        #expect(page.draft.note.due == TaskDue(day: friday, time: LocalTime("15:30")))
        #expect(page.creation(unnamed: "Unnamed", rules: model.nameProblem(in:)) == nil,
                "left untouched, the drop makes nothing")
    }

    @Test func aHabitFromATimelineDropGetsThatTimeAsItsReminder() throws {
        let model = try makeModel()
        var page = model.newItemPage(NewItemSeed(kind: .task, placement: .timeline(day: friday, time: LocalTime("15:30"))))
        page.kind = .habit
        #expect(page.draft.note.reminderTimes == [LocalTime("15:30")])
        #expect(page.draft.note.due == nil)
    }

    @Test func aPoolPlacementPutsTheNewTaskAtTheGapAndInItsSection() async throws {
        let model = try makeModel()
        let today = model.context().today
        let placement = NewItemPlacement.pool(order: ["A", NewItemPlacement.gap, "B"], section: "day", day: today)
        var page = model.newItemPage(NewItemSeed(kind: .task, placement: placement))
        page.name = "New"

        #expect(await model.createOnReturn(from: page) == "New")

        let plan = model.plan(at: model.clock.now)
        #expect(plan.poolNames.filter(["A", "New", "B"].contains) == ["A", "New", "B"])
        #expect(model.sections(on: today).membership["New"] == "day")
    }

    /// Leaving the page with Back puts the note there as well, in the section it was let go in.
    @Test func leavingThePagePutsItInTheSectionItWasLetGoIn() async throws {
        let model = try makeModel()
        let today = model.context().today
        var page = model.newItemPage(NewItemSeed(kind: .task, placement: .pool(order: ["A", "B", NewItemPlacement.gap],
                                                                               section: "evening", day: today)))
        page.name = "Later"
        #expect(await model.create(from: page, unnamed: "Unnamed"))
        let sections = model.plan(at: model.clock.now).sections
        #expect(sections.first { $0.id == "evening" }?.items.map(\.id) == ["Later"])
        #expect(sections.first { $0.id == "day" }?.items.map(\.id).contains("Later") == false)
    }
}
