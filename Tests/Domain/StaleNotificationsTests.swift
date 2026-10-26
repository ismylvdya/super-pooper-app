import Foundation
import Testing
@testable import SuperPooper

/// A notification goes with its logical day: a habit not marked by the boundary does not wait into the next day.
struct StaleNotificationsTests {
    private let today = LocalDate(year: 2026, month: 10, day: 26)!

    @Test func notificationsOfEarlierDaysAreCleared() {
        let delivered: [(identifier: String, day: String?)] = [("sp|water", "2026-10-25"), ("sp|read", "2026-10-26"),
                                                               ("sp|old", "2026-10-20"), ("sp|unknown", nil)]
        #expect(StaleNotifications.identifiers(delivered, today: today) == ["sp|water", "sp|old"])
    }

    /// After midnight but before the boundary it is still the evening's day, so its notifications stay.
    @Test func theDayEndsAtTheBoundaryNotAtMidnight() {
        let calendar = TestCalendar.calendar
        let night = calendar.date(from: DateComponents(year: 2026, month: 10, day: 27, hour: 2))!
        let context = DayContext(now: night, calendar: calendar, boundary: LocalTime(hour: 4, minute: 0)!, energyHour: LocalTime(hour: 12, minute: 0)!)
        #expect(!StaleNotifications.isOver(today, today: context.today))
        #expect(StaleNotifications.isOver(today, today: context.logicalDay(of: night.addingTimeInterval(3 * 3600))))
    }
}
