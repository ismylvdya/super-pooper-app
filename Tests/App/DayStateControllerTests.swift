import Foundation
import Testing
@testable import SuperPooperApp

/// What the user decided about today, kept for this day only.
@MainActor
struct DayStateControllerTests {
    private func makeDay() throws -> DayStateController {
        try #require(PreviewModel.make()).model.parts.day
    }

    /// The problems banner comes only for more problems than the user was last told about.
    @Test func onlyMoreProblemsAreNew() throws {
        let day = try makeDay()
        #expect(day.announceProblems(2))
        #expect(!day.announceProblems(2))
        #expect(!day.announceProblems(1))
        #expect(day.announceProblems(3))
    }

}
