import Foundation
import Testing
@testable import SuperPooperApp

/// The logical day around its boundary (04:00 by default), including the nights the clocks change.
/// Belgrade: summer time ends on 2026-10-25 (03:00 → 02:00) and starts on 2026-03-29 (02:00 → 03:00).
@Suite("Logical day and clock changes")
struct LogicalDayTests {
    private func today(_ day: String, _ time: String) -> String {
        TestCalendar.context(day, time).today.isoString
    }

    @Test func beforeTheBoundaryItIsStillYesterday() {
        #expect(today("2026-10-22", "03:59") == "2026-10-21")
        #expect(today("2026-10-22", "04:00") == "2026-10-22")
    }

    @Test func theNightTheClocksGoBackKeepsTheBoundaryAtFour() {
        #expect(today("2026-10-25", "03:30") == "2026-10-24")
        #expect(today("2026-10-25", "04:00") == "2026-10-25")
    }

    @Test func theNightTheClocksGoForwardKeepsTheBoundaryAtFour() {
        #expect(today("2026-03-29", "03:30") == "2026-03-28")
        #expect(today("2026-03-29", "04:30") == "2026-03-29")
    }

    @Test func aMomentBelongsToTheLogicalDayOfItsWallClock() {
        let context = TestCalendar.context("2026-10-22", "13:00")
        #expect(context.logicalDay(of: TestCalendar.date("2026-10-23", "01:30")).isoString == "2026-10-22")
        #expect(context.logicalDay(of: TestCalendar.date("2026-10-23", "04:00")).isoString == "2026-10-23")
    }

    /// A habit made in Obsidian at 01:00 with no start date: it is still the evening's day, so the habit is in that day
    /// (with a 04:00 boundary), and its history counts from it.
    @Test func aHabitCreatedAfterMidnightStartsOnTheEveningsDay() {
        let habit = makeHabit("Stretch", rule: "FREQ=WEEKLY;BYDAY=WE") { $0.dateCreated = TestCalendar.date("2026-10-22", "01:00") }
        let wednesday = LocalDate(isoString: TestCalendar.wednesday)!
        #expect(TaskOccurrence(days: TestCalendar.days).occurs(habit, on: wednesday))
        #expect(HabitHistory(task: habit, days: TestCalendar.days).start(today: wednesday.adding(days: 2)) == wednesday)
    }
}
