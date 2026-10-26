import Foundation
import Testing
@testable import SuperPooper

/// The day's name on Today: "Today" or the date; in landscape the weekday in two letters.
@MainActor
struct DayNameTests {
    private let wednesday = LocalDate(isoString: TestCalendar.wednesday)!

    /// The date reads the way the phone's region writes it; in Britain the day goes first.
    @Test func anotherDayIsNamedByItsDate() {
        var calendar = TestCalendar.calendar
        calendar.locale = Locale(identifier: "en_GB")
        #expect(DayName.title(wednesday, offset: 0, style: .date, calendar: calendar) == L10n.string("day.today"))
        #expect(DayName.title(wednesday.adding(days: 1), offset: 1, style: .date, calendar: calendar) == "22 Oct")
        #expect(DayName.title(wednesday.adding(days: -1), offset: -1, style: .date, calendar: calendar) == "20 Oct")
    }

    @Test func landscapeNamesTheWeekdayInTwoLetters() {
        let calendar = TestCalendar.calendar
        #expect(DayName.title(wednesday, offset: 0, style: .weekday, calendar: calendar) == "We")
        #expect(Set(DayName.all(.weekday, around: wednesday, calendar: calendar)) == ["Mo", "Tu", "We", "Th", "Fr", "Sa", "Su"])
        #expect(DayName.all(.date, around: wednesday, calendar: calendar).count == 13)
    }
}
