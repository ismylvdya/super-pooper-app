import Foundation
import Testing
@testable import SuperPooperApp

/// Times are wall-clock unless an item keeps them in a zone of its own; then they move to the phone's zone.
struct ZonedTimesTests {
    private var berlin: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Berlin")!
        return calendar
    }

    @Test func withoutAZoneTimesStayAsTheyAre() {
        let task = makeTask("Call") { $0.due = TaskDue("2026-10-21T09:00"); $0.reminderTimes = [LocalTime("09:00")] }
        #expect(ZonedTimes.local(task, calendar: berlin, today: LocalDate("2026-10-21")) == task)
    }

    @Test func aZonedTimeMovesToThePhonesZone() {
        let task = makeTask("Call") {
            $0.timeZone = "Europe/Moscow"
            $0.due = TaskDue("2026-10-21T09:00")
            $0.reminderTimes = [LocalTime("01:30")]
        }
        let local = ZonedTimes.local(task, calendar: berlin, today: LocalDate("2026-10-21"))
        // On 21 October Moscow is UTC+3 and Berlin, still on summer time, UTC+2.
        #expect(local.due == TaskDue("2026-10-21T08:00"))
        #expect(local.reminderTimes == [LocalTime("00:30")])
    }

    @Test func theSignatureWarningIsDueWithinTheLeadTime() {
        let now = Date(timeIntervalSince1970: 1_000_000)
        #expect(SigningExpiry.isSoon(expiration: now.addingTimeInterval(3600), leadHours: 24, now: now))
        #expect(!SigningExpiry.isSoon(expiration: now.addingTimeInterval(3 * 24 * 3600), leadHours: 24, now: now))
        #expect(!SigningExpiry.isSoon(expiration: now.addingTimeInterval(-60), leadHours: 24, now: now))
    }
}
