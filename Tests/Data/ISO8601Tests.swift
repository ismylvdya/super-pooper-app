import Foundation
import Testing
@testable import SuperPooperApp

/// The shared ISO 8601 formatters: one writer per zone, safe to use from several tasks at once.
struct ISO8601Tests {
    private let moment = TestCalendar.date(TestCalendar.wednesday, "13:25")

    @Test func eachZoneGetsItsOwnOffset() throws {
        let jakarta = try #require(TimeZone(identifier: "Asia/Jakarta"))
        #expect(ISO8601.format(moment, timeZone: TestCalendar.timeZone) == "2026-10-21T13:25:00+02:00")
        #expect(ISO8601.format(moment, timeZone: jakarta) == "2026-10-21T18:25:00+07:00")
        #expect(ISO8601.formatWithMilliseconds(moment, timeZone: TestCalendar.timeZone) == "2026-10-21T13:25:00.000+02:00")
        #expect(ISO8601.format(moment, timeZone: TestCalendar.timeZone) == "2026-10-21T13:25:00+02:00")
    }

    /// TaskNotes writes `+00:00` at UTC+0 (London in winter, Reykjavík, UTC itself); the formatter alone wrote `Z`.
    @Test func aZeroOffsetIsWrittenAsTaskNotesWritesIt() throws {
        let utc = try #require(TimeZone(identifier: "UTC"))
        let london = try #require(TimeZone(identifier: "Europe/London"))
        let winter = TestCalendar.date("2026-12-02", "13:25")
        #expect(ISO8601.format(moment, timeZone: utc) == "2026-10-21T11:25:00+00:00")
        #expect(ISO8601.formatWithMilliseconds(moment, timeZone: utc) == "2026-10-21T11:25:00.000+00:00")
        #expect(ISO8601.formatWithMilliseconds(winter, timeZone: london) == "2026-12-02T12:25:00.000+00:00")
        #expect(ISO8601.parse("2026-10-21T11:25:00.000+00:00") == moment)
    }

    @Test func parsingFromManyTasksAtOnceAgrees() async {
        let texts = (0..<200).map { "2026-10-21T13:25:\(String(format: "%02d", $0 % 60)).\(String(format: "%03d", $0))+02:00" }
        let parsed = await withTaskGroup(of: (Int, Date?).self) { group in
            for (index, text) in texts.enumerated() { group.addTask { (index, ISO8601.parse(text)) } }
            var result: [Int: Date] = [:]
            for await (index, date) in group { result[index] = date }
            return result
        }
        #expect(parsed.count == texts.count)
        #expect(texts.indices.allSatisfy { parsed[$0] == ISO8601.parse(texts[$0]) })
    }
}
