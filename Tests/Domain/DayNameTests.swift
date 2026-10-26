import Foundation
import Testing
@testable import SuperPooper

/// The day's name on Today: "Today" or the date; in landscape "Tod" or the weekday in three letters.
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

    @Test func landscapeNamesTheWeekdayInThreeLettersAndTodayAsTod() {
        let calendar = TestCalendar.calendar
        #expect(DayName.title(wednesday, offset: 0, style: .weekday, calendar: calendar) == L10n.string("day.todayShort"))
        #expect(DayName.title(wednesday.adding(days: 1), offset: 1, style: .weekday, calendar: calendar) == "Thu")
        #expect(Set(DayName.all(.weekday, around: wednesday, calendar: calendar))
            == [L10n.string("day.todayShort"), "Thu", "Fri", "Sat", "Sun", "Mon", "Tue"])
        #expect(DayName.all(.date, around: wednesday, calendar: calendar).count == 13)
    }
}
