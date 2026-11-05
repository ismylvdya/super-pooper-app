import Foundation
import Testing
@testable import SuperPooperApp

/// Time zones are shown as their offset from UTC, with the city in the list.
struct TimeZoneNameTests {
    private let winter = TestCalendar.date("2026-01-15", "12:00")

    @Test func zonesAreShownAsOffsets() throws {
        func offset(_ id: String) throws -> String { TimeZoneName.offset(try #require(TimeZone(identifier: id)), at: winter) }
        #expect(try offset("Europe/Moscow") == "+3 UTC")
        #expect(try offset("America/New_York") == "−5 UTC")
        #expect(try offset("Asia/Kolkata") == "+5:30 UTC")
        #expect(try offset("Europe/London") == "+0 UTC")
    }

    @Test func theCityComesFromTheIdentifier() {
        #expect(TimeZoneName.city("Europe/Moscow") == "Moscow")
        #expect(TimeZoneName.city("America/Port_of_Spain") == "Port of Spain")
    }
}
