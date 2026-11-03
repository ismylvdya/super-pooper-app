import Foundation
import Testing
@testable import SuperPooperApp

/// Dates and times typed into a name, found by the words of `date-grammar.json`. Now is Wednesday 2026-11-04 11:30,
/// the day boundary 04:00.
struct DateDetectorTests {
    private let detector = DateDetector(grammar: TestConfig.dateGrammar)
    private let wednesday = TestCalendar.context("2026-11-04", "11:30")

    @Test(arguments: [
        ("Call mom in 5 min", "2026-11-04", "11:35", "in 5 min"),
        ("Pay rent in 2 hours", "2026-11-04", "13:30", "in 2 hours"),
        ("Pay rent in 3 days", "2026-11-07", nil, "in 3 days"),
        ("Dentist today", "2026-11-04", nil, "today"),
        ("Dentist tomorrow 18:20", "2026-11-05", "18:20", "tomorrow 18:20"),
        ("Gym mon", "2026-11-09", nil, "mon"),
        ("Gym Monday", "2026-11-09", nil, "Monday"),
        ("Gym wed", "2026-11-11", nil, "wed"),
        ("Plan next week", "2026-11-09", nil, "next week"),
        ("Visa 6 Nov", "2026-11-06", nil, "6 Nov"),
        ("Visa Nov 6", "2026-11-06", nil, "Nov 6"),
        ("Visa 6.11", "2026-11-06", nil, "6.11"),
        ("Visa 06.11.2026", "2026-11-06", nil, "06.11.2026"),
        ("Visa 3.11", "2027-11-03", nil, "3.11"),
        ("Run 6:20", "2026-11-05", "06:20", "6:20"),
        ("Run 18:20", "2026-11-04", "18:20", "18:20"),
        ("Run at 6", "2026-11-05", "06:00", "at 6"),
        ("Run 6pm", "2026-11-04", "18:00", "6pm"),
        ("Run 12am", "2026-11-05", "00:00", "12am"),
        ("Visa 6 Nov at 9 done", "2026-11-06", "09:00", "6 Nov at 9"),
        ("18:20 call Anna tomorrow", "2026-11-05", "18:20", "18:20 tomorrow"),
    ] as [(String, String, String?, String)])
    func detects(text: String, day: String, time: String?, matched: String) throws {
        let found = try #require(detector.detect(in: text, context: wednesday))
        #expect(found.due == TaskDue(day: LocalDate(day), time: time.map { LocalTime($0) }))
        #expect(found.ranges.map { String(text[$0]) }.joined(separator: " ") == matched)
    }

    /// Words of the grammar count only whole; a month only next to a day number; "in N" only with a unit.
    @Test func ordinaryWordsAreNotDates() {
        for text in ["Buy monitor", "Call Monica", "Room 6.11b", "May I ask", "in 2 boxes", "Read 1984", "Todayish",
                     "Version 6.11.20", "Sunflower seeds", "Atlas 6"] {
            #expect(detector.detect(in: text, context: wednesday) == nil, "\(text)")
        }
    }

    @Test func impossibleDatesAreNotDetected() {
        for text in ["Due 31.02", "Due 29.02.2027", "At 25:10", "At 6:75", "At 13pm", "Due 32 Nov", "Due 6.13"] {
            #expect(detector.detect(in: text, context: wednesday) == nil, "\(text)")
        }
    }

    /// At 01:30 it is still the logical 4 November: "today" is the 4th, a time still to come tonight stays tonight.
    @Test func beforeTheBoundaryTheLogicalDayCounts() throws {
        let night = TestCalendar.context("2026-11-05", "01:30")
        #expect(try #require(detector.detect(in: "X today", context: night)).due == TaskDue(day: LocalDate("2026-11-04")))
        #expect(try #require(detector.detect(in: "X tomorrow", context: night)).due == TaskDue(day: LocalDate("2026-11-05")))
        #expect(try #require(detector.detect(in: "X 18:20", context: night)).due
            == TaskDue(day: LocalDate("2026-11-05"), time: LocalTime("18:20")))
        #expect(try #require(detector.detect(in: "X 02:00", context: night)).due
            == TaskDue(day: LocalDate("2026-11-05"), time: LocalTime("02:00")))
        #expect(try #require(detector.detect(in: "X 01:00", context: night)).due
            == TaskDue(day: LocalDate("2026-11-06"), time: LocalTime("01:00")), "01:00 has just passed: the next night")
        #expect(try #require(detector.detect(in: "X tomorrow 01:00", context: night)).due
            == TaskDue(day: LocalDate("2026-11-06"), time: LocalTime("01:00")), "the night after the logical tomorrow")
    }

    @Test func removingLeavesTheRestOfTheName() throws {
        let text = "Dentist tomorrow at 6pm please"
        let found = try #require(detector.detect(in: text, context: wednesday))
        #expect(found.due == TaskDue(day: LocalDate("2026-11-05"), time: LocalTime("18:00")))
        #expect(DateDetector.removing(found, from: text) == "Dentist please")
        let apart = "Call 18:20 Anna tomorrow"
        #expect(DateDetector.removing(try #require(detector.detect(in: apart, context: wednesday)), from: apart) == "Call Anna")
    }

    /// Case does not matter, as in the system apps.
    @Test func caseDoesNotMatter() throws {
        #expect(try #require(detector.detect(in: "Gym TOMORROW", context: wednesday)).due == TaskDue(day: LocalDate("2026-11-05")))
    }
}
