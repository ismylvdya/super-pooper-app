import Foundation
import Testing
@testable import SuperPooperApp

/// The day's name on Today (.25718): "Today", "Yesterday", "Tomorrow" or the date with its weekday; in landscape "Tod" or
/// the weekday in three letters.
@MainActor
struct DayNameTests {
    private let wednesday = LocalDate(isoString: TestCalendar.wednesday)!

    /// The date reads the way the phone's region writes it; in Britain the day goes first.
    @Test func anotherDayIsNamedByItsDate() {
        var calendar = TestCalendar.calendar
        calendar.locale = Locale(identifier: "en_GB")
        #expect(DayName.title(wednesday, offset: 0, style: .date, calendar: calendar) == "Today")
        #expect(DayName.title(wednesday.adding(days: 1), offset: 1, style: .date, calendar: calendar) == "Tomorrow")
        #expect(DayName.title(wednesday.adding(days: -1), offset: -1, style: .date, calendar: calendar) == "Yesterday")
        #expect(DayName.title(wednesday.adding(days: 5), offset: 5, style: .date, calendar: calendar) == "26 Oct · Mon")
        #expect(DayName.title(wednesday.adding(days: -2), offset: -2, style: .date, calendar: calendar) == "19 Oct · Mon")
    }

    /// The frame holds the widest name: "Yesterday" and every date with its weekday, so the arrows never move.
    @Test func theFrameIsMeasuredByTheWidestName() {
        let names = DayName.all(.date, around: wednesday, calendar: TestCalendar.calendar)
        #expect(names.contains("Yesterday") && names.contains("Today") && names.contains("Tomorrow"))
        #expect(names.count == 3 + 12 * 7)
        #expect(Set(names.compactMap { $0.split(separator: " ").last.map(String.init) }).isSuperset(of: ["Mon", "Wed", "Sun"]))
        #expect(DayName.widest(["Today", "Yesterday", "Tomorrow"]) { Double($0.count) } == "Yesterday")
        #expect(DayName.widest([]) { Double($0.count) } == nil)
    }

    @Test func landscapeNamesTheWeekdayInThreeLettersAndTodayAsTod() {
        let calendar = TestCalendar.calendar
        #expect(DayName.title(wednesday, offset: 0, style: .weekday, calendar: calendar) == L10n.string("day.todayShort"))
        #expect(DayName.title(wednesday.adding(days: 1), offset: 1, style: .weekday, calendar: calendar) == "Thu")
        #expect(Set(DayName.all(.weekday, around: wednesday, calendar: calendar))
            == [L10n.string("day.todayShort"), "Thu", "Fri", "Sat", "Sun", "Mon", "Tue"])
    }
}
