import Foundation
import Testing
@testable import SuperPooperApp

/// Zone lists go by the offset the zone has on the day asked about, and that offset follows the zone's summer and winter time.
struct TimeZoneGroupsTests {
    private let priority = ["Europe/Moscow", "Asia/Bangkok", "Europe/Istanbul", "Europe/Belgrade"]
    private let winter = Date(timeIntervalSince1970: 1_768_435_200) // 15 January 2026
    private let summer = Date(timeIntervalSince1970: 1_784_073_600) // 15 July 2026

    private func group(with id: String, at date: Date) throws -> TimeZoneGroup {
        try #require(TimeZoneGroups.groups(of: TimeZone.knownTimeZoneIdentifiers, priority: priority, at: date).first { $0.identifiers.contains(id) })
    }

    @Test func theUsersCitiesComeFirstInTheirOffset() throws {
        #expect(try group(with: "Europe/Moscow", at: winter).identifiers.prefix(2) == ["Europe/Moscow", "Europe/Istanbul"])
        #expect(try group(with: "Asia/Bangkok", at: winter).identifiers.first == "Asia/Bangkok")
        #expect(try group(with: "Europe/Belgrade", at: winter).identifiers.first == "Europe/Belgrade")
    }

    @Test func rowsGoByTheirOffset() {
        let offsets = TimeZoneGroups.groups(of: TimeZone.knownTimeZoneIdentifiers, priority: priority, at: winter).map(\.offsetSeconds)
        #expect(offsets == offsets.sorted())
        #expect(offsets.first ?? 0 < 0 && offsets.last ?? 0 > 0)
    }

    @Test func summerTimeMovesAZoneByItselfAndOnlyThoseThatHaveIt() throws {
        #expect(try group(with: "Europe/Belgrade", at: winter).offsetSeconds == 3600)
        #expect(try group(with: "Europe/Belgrade", at: summer).offsetSeconds == 7200)
        #expect(try group(with: "Europe/Moscow", at: winter).offsetSeconds == 10800)
        #expect(try group(with: "Europe/Moscow", at: summer).offsetSeconds == 10800)
        #expect(try group(with: "Asia/Bangkok", at: winter).offsetSeconds == 25200)
        #expect(try group(with: "Asia/Bangkok", at: summer).offsetSeconds == 25200)
    }

    /// Lagos has +1 all year, Belgrade only in winter: picking the row of one never gives the other's summer.
    @Test func zonesThatPartAtTheNextChangeHaveRowsOfTheirOwn() throws {
        #expect(try group(with: "Africa/Lagos", at: winter).identifiers.contains("Europe/Belgrade") == false)
    }

    @Test func aTaskKeptInAZoneFollowsItsSummerTime() throws {
        var phone = Calendar(identifier: .gregorian)
        phone.timeZone = try #require(TimeZone(identifier: "Asia/Bangkok"))
        func shown(on day: String) throws -> LocalTime? {
            let date = try #require(LocalDate(isoString: day))
            let task = makeTask("T") { task in
                task.timeZone = "Europe/Belgrade"
                task.due = TaskDue(day: date, time: LocalTime(string: "09:00"))
            }
            return ZonedTimes.local(task, calendar: phone, today: date).due?.time
        }
        #expect(try shown(on: "2026-01-15") == LocalTime(string: "15:00"))
        #expect(try shown(on: "2026-07-15") == LocalTime(string: "14:00"))
    }
}
