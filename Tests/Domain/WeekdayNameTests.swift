import Foundation
import Testing
@testable import SuperPooperApp

/// Weekday and month names come from the app calendar: Monday is "Monday", "Mon", "M" in English.
struct WeekdayNameTests {
    private let calendar = AppCalendar.make(timeZone: TestCalendar.calendar.timeZone, locale: Locale(identifier: "en_US"))

    @Test func weekdaysAreNamedInThreeLengths() {
        #expect(Weekday.monday.name(.full, in: calendar) == "Monday")
        #expect(Weekday.sunday.name(.short, in: calendar) == "Sun")
        #expect(Weekday.wednesday.name(.initial, in: calendar) == "W")
    }

    @Test func monthsHaveInitials() {
        #expect(MonthName.initial(1, in: calendar) == "J")
        #expect(MonthName.initial(12, in: calendar) == "D")
    }
}
