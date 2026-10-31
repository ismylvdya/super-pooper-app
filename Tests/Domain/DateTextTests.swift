import Foundation
import Testing
@testable import SuperPooperApp

/// Days on screen and in the date pickers go through the app calendar's zone, never the system's: the reported bug
/// was a task set to 6 November shown on the 7th after a time zone change.
@MainActor
struct DateTextTests {
    /// UTC+14: midnight there is the previous afternoon almost everywhere else, so a system-zone formatter shows the
    /// day before.
    private let farEast = TestCalendar.calendar(in: "Pacific/Kiritimati")

    @Test func aDateAWeekAwayIsNamedInTheAppCalendarsZone() {
        let context = DayContext(now: LocalDate("2026-10-21").startDate(in: farEast, offset: LocalTime("13:25")), calendar: farEast,
                                 boundary: TestConfig.defaults.day.boundary, energyHour: TestConfig.defaults.day.energyHour)
        #expect(DueText.format(TaskDue("2026-11-06"), context: context) == "Nov 6")
        #expect(DueText.format(TaskDue("2026-11-06T09:00"), context: context) == L10n.format("due.dayAndTime", "Nov 6", "09:00"))
    }

    @Test func aDayIsFormattedAsItsOwnDateInAnyZone() {
        for zone in ["Pacific/Kiritimati", "Asia/Jakarta", "Europe/Belgrade", "America/New_York", "Pacific/Pago_Pago"] {
            let calendar = TestCalendar.calendar(in: zone)
            #expect(DateText.format(LocalDate("2026-11-06"), .dateTime.month(.abbreviated).day(), calendar: calendar) == "Nov 6")
        }
    }

    /// The date picker's value is noon of the day: read in the zone the phone has just left (Jakarta, six hours
    /// ahead of Belgrade) or the one it has just arrived in, it is still 6 November.
    @Test func aPickedDayStaysTheSameAcrossAZoneChange() {
        let jakarta = TestCalendar.calendar(in: "Asia/Jakarta")
        let belgrade = TestCalendar.calendar(in: "Europe/Belgrade")
        let day = LocalDate("2026-11-06")
        #expect(LocalDate(DayField.date(of: day, calendar: jakarta), in: belgrade) == day)
        #expect(LocalDate(DayField.date(of: day, calendar: belgrade), in: jakarta) == day)
        #expect(LocalDate(DayField.date(of: day, calendar: belgrade), in: belgrade) == day)
    }
}
