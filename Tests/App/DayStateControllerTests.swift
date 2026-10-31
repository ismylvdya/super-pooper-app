import Foundation
import Testing
@testable import SuperPooperApp

/// What the user decided about today, kept for this day only.
@MainActor
struct DayStateControllerTests {
    private func makeDay() throws -> DayStateController {
        try #require(PreviewModel.make()).model.parts.day
    }

    @Test func aNameIsKeptOnceWhateverItsCase() throws {
        let day = try makeDay()
        day.skip("Drink water")
        day.skip("drink water")
        day.postpone("Report")
        day.postpone("report")
        #expect(day.dayState.skipped == ["Drink water"])
        #expect(day.postponedNames == ["Report"])
        day.unpostpone("REPORT")
        #expect(day.postponedNames.isEmpty)
    }

    /// The problems banner comes only for more problems than the user was last told about.
    @Test func onlyMoreProblemsAreNew() throws {
        let day = try makeDay()
        #expect(day.announceProblems(2))
        #expect(!day.announceProblems(2))
        #expect(!day.announceProblems(1))
        #expect(day.announceProblems(3))
    }

    @Test func aRenamedNoteKeepsItsPlacesInTheDay() throws {
        let day = try makeDay()
        day.skip("Water")
        day.postpone("Report")
        day.setManualOrder(["Report", "Call"])
        day.followRename(from: "Report", to: "Final report")
        #expect(day.dayState.postponed == ["Final report"])
        #expect(day.dayState.manualOrder == ["Final report", "Call"])
        #expect(day.dayState.skipped == ["Water"])
    }
}
