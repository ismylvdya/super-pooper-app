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

    @Test func anEarlyTurnSurvivesReadingTheStoreAndReachingTheBoundary() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let files = JSONFileStore(directory: directory)
        let store = DayStateStore(store: files)
        let evening = TestCalendar.context("2026-10-21", "20:00")
        let target = evening.today.adding(days: 1)
        var before = DayState(day: evening.today)
        before.skipped = ["Yesterday only"]
        before.earlyTurn = target
        try store.save(before)
        #expect(store.earlyTurn == target)

        let reopened = DayStateStore(store: files)
        var rolled = reopened.load(for: evening)
        #expect(rolled.day == target && rolled.skipped.isEmpty)
        rolled.skipped = ["Skipped after the early turn"]
        try reopened.save(rolled)
        let boundary = DayContext(now: evening.dayEnd, calendar: evening.calendar,
                                  boundary: evening.boundary, energyHour: evening.energyHour)
        #expect(reopened.load(for: boundary) == rolled)
    }

}
