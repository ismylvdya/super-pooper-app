import Foundation
import Testing
@testable import SuperPooperApp

private func day(_ iso: String) -> LocalDate {
    guard let value = LocalDate(isoString: iso) else { preconditionFailure("Invalid fixture date \(iso)") }
    return value
}

@Suite("Recurrence rule parsing")
struct RecurrenceRuleParsingTests {
    @Test func parsesTimedDailyRuleWrittenByTaskNotes() throws {
        let raw = "DTSTART:20261001T090000Z;FREQ=DAILY"
        let rule = try RecurrenceRule.parse(raw).get()

        #expect(rule.raw == raw)
        #expect(rule.startDate == day("2026-10-01"))
        #expect(rule.startTime == LocalTime(hour: 9, minute: 0))
        #expect(rule.frequency == .daily)
        #expect(rule.interval == 1)
        #expect(rule.byDay.isEmpty && rule.byMonthDay.isEmpty && rule.byMonth.isEmpty)
        #expect(rule.count == nil)
        #expect(rule.untilDate == nil && rule.untilTime == nil)
        #expect(rule.weekStart == .monday)
    }

    @Test func parsesDateOnlyBiweeklyRuleWrittenByTaskNotes() throws {
        let rule = try RecurrenceRule.parse("DTSTART:20261001;FREQ=WEEKLY;INTERVAL=2;BYDAY=SA").get()

        #expect(rule.startDate == day("2026-10-01"))
        #expect(rule.startTime == nil)
        #expect(rule.frequency == .weekly)
        #expect(rule.interval == 2)
        #expect(rule.byDay == [RecurrenceWeekday(weekday: .saturday, ordinal: nil)])
    }

    @Test func parsesEverySupportedPart() throws {
        let rule = try RecurrenceRule.parse(
            "DTSTART:20260105T073000Z;FREQ=YEARLY;INTERVAL=3;BYDAY=2MO,-1FR,+1TU,SU;BYMONTHDAY=1,-1;"
                + "BYMONTH=1,6;COUNT=10;UNTIL=20271231T235959Z;WKST=SU"
        ).get()

        #expect(rule.startDate == day("2026-01-05"))
        #expect(rule.startTime == LocalTime(hour: 7, minute: 30))
        #expect(rule.frequency == .yearly)
        #expect(rule.interval == 3)
        #expect(rule.byDay == [
            RecurrenceWeekday(weekday: .monday, ordinal: 2),
            RecurrenceWeekday(weekday: .friday, ordinal: -1),
            RecurrenceWeekday(weekday: .tuesday, ordinal: 1),
            RecurrenceWeekday(weekday: .sunday, ordinal: nil),
        ])
        #expect(rule.byMonthDay == [1, -1])
        #expect(rule.byMonth == [1, 6])
        #expect(rule.count == 10)
        #expect(rule.untilDate == day("2027-12-31"))
        #expect(rule.untilTime == LocalTime(hour: 23, minute: 59))
        #expect(rule.weekStart == .sunday)
    }

    @Test func parsesDateOnlyUntilWithoutDtstart() throws {
        let rule = try RecurrenceRule.parse("FREQ=MONTHLY;BYMONTHDAY=-1;UNTIL=20261231").get()

        #expect(rule.startDate == nil && rule.startTime == nil)
        #expect(rule.byMonthDay == [-1])
        #expect(rule.untilDate == day("2026-12-31"))
        #expect(rule.untilTime == nil)
    }

    @Test func keysValuesAndPrefixesAreCaseInsensitive() throws {
        let rule = try RecurrenceRule.parse("dtstart:20261001t090000z;rrule:freq=monthly;byday=-1fr;wkst=su").get()

        #expect(rule.startDate == day("2026-10-01"))
        #expect(rule.startTime == LocalTime(hour: 9, minute: 0))
        #expect(rule.frequency == .monthly)
        #expect(rule.byDay == [RecurrenceWeekday(weekday: .friday, ordinal: -1)])
        #expect(rule.weekStart == .sunday)
    }

    @Test(arguments: [
        "DTSTART:20261001T090000Z\nRRULE:FREQ=DAILY;INTERVAL=2",
        "DTSTART:20261001T090000Z\r\nRRULE:FREQ=DAILY;INTERVAL=2",
        "RRULE:FREQ=DAILY;INTERVAL=2\nDTSTART:20261001T090000Z",
    ])
    func acceptsDtstartOnItsOwnLine(raw: String) throws {
        let rule = try RecurrenceRule.parse(raw).get()

        #expect(rule.startDate == day("2026-10-01"))
        #expect(rule.startTime == LocalTime(hour: 9, minute: 0))
        #expect(rule.frequency == .daily)
        #expect(rule.interval == 2)
    }

    @Test func ignoresWhitespaceAndEmptyParts() throws {
        let rule = try RecurrenceRule.parse("  FREQ = WEEKLY ; ; BYDAY = MO, FR ;").get()

        #expect(rule.frequency == .weekly)
        #expect(rule.byDay.map(\.weekday) == [.monday, .friday])
    }

    @Test(arguments: ["", "   ", ";;", "\n"])
    func rejectsEmptyInput(raw: String) {
        #expect(RecurrenceRule.parse(raw) == .failure(.empty))
    }

    @Test(arguments: ["DTSTART:20261001", "INTERVAL=2;BYDAY=MO"])
    func rejectsRuleWithoutFrequency(raw: String) {
        #expect(RecurrenceRule.parse(raw) == .failure(.missingFrequency))
    }

    @Test(arguments: [
        ("FREQ=MONTHLY;BYDAY=MO;BYSETPOS=1", "BYSETPOS"),
        ("FREQ=DAILY;BYHOUR=9", "BYHOUR"),
        ("FREQ=DAILY;BYMINUTE=30", "BYMINUTE"),
        ("FREQ=YEARLY;BYWEEKNO=20", "BYWEEKNO"),
        ("FREQ=YEARLY;BYYEARDAY=100", "BYYEARDAY"),
        ("FREQ=HOURLY", "FREQ=HOURLY"),
        ("FREQ=minutely", "FREQ=MINUTELY"),
        ("FREQ=SECONDLY", "FREQ=SECONDLY"),
        ("DTSTART:20261001\nRRULE:FREQ=DAILY\nEXDATE:20261005", "EXDATE"),
        ("FREQ=DAILY\nRDATE:20261005", "RDATE"),
        ("FREQ=DAILY\nEXRULE:FREQ=WEEKLY", "EXRULE"),
        ("DTSTART;TZID=Europe/Moscow:20261001T090000;FREQ=DAILY", "DTSTART"),
        ("FREQ=DAILY;DTSTART=20261001", "DTSTART"),
        ("FREQ=DAILY;garbage", "garbage"),
        ("every day", "every day"),
    ])
    func rejectsUnsupportedParts(raw: String, part: String) {
        #expect(RecurrenceRule.parse(raw) == .failure(.unsupportedPart(part)))
    }

    @Test(arguments: [
        ("FREQ=FORTNIGHTLY", "FREQ", "FORTNIGHTLY"),
        ("FREQ=DAILY;INTERVAL=0", "INTERVAL", "0"),
        ("FREQ=DAILY;INTERVAL=-2", "INTERVAL", "-2"),
        ("FREQ=DAILY;INTERVAL=two", "INTERVAL", "two"),
        ("FREQ=DAILY;INTERVAL=10001", "INTERVAL", "10001"),
        ("FREQ=DAILY;COUNT=0", "COUNT", "0"),
        ("FREQ=DAILY;COUNT=", "COUNT", ""),
        ("FREQ=WEEKLY;BYDAY=XX", "BYDAY", "XX"),
        ("FREQ=WEEKLY;BYDAY=MO,,TU", "BYDAY", "MO,,TU"),
        ("FREQ=MONTHLY;BYDAY=0MO", "BYDAY", "0MO"),
        ("FREQ=MONTHLY;BYDAY=54MO", "BYDAY", "54MO"),
        ("FREQ=MONTHLY;BYDAY=1.5MO", "BYDAY", "1.5MO"),
        ("FREQ=MONTHLY;BYMONTHDAY=0", "BYMONTHDAY", "0"),
        ("FREQ=MONTHLY;BYMONTHDAY=32", "BYMONTHDAY", "32"),
        ("FREQ=MONTHLY;BYMONTHDAY=-32", "BYMONTHDAY", "-32"),
        ("FREQ=YEARLY;BYMONTH=13", "BYMONTH", "13"),
        ("FREQ=WEEKLY;WKST=2MO", "WKST", "2MO"),
        ("FREQ=DAILY;UNTIL=2026-12-31", "UNTIL", "2026-12-31"),
        ("FREQ=DAILY;UNTIL=20261231Z", "UNTIL", "20261231Z"),
        ("DTSTART:20261301;FREQ=DAILY", "DTSTART", "20261301"),
        ("DTSTART:20260230;FREQ=DAILY", "DTSTART", "20260230"),
        ("DTSTART:20261001T250000Z;FREQ=DAILY", "DTSTART", "20261001T250000Z"),
        ("DTSTART:20261001T090060Z;FREQ=DAILY", "DTSTART", "20261001T090060Z"),
        ("DTSTART:20261001T0900;FREQ=DAILY", "DTSTART", "20261001T0900"),
        ("FREQ=DAILY;FREQ=WEEKLY", "FREQ", "WEEKLY"),
        ("DTSTART:20261001;DTSTART:20261002;FREQ=DAILY", "DTSTART", "20261002"),
    ])
    func rejectsInvalidValues(raw: String, part: String, value: String) {
        #expect(RecurrenceRule.parse(raw) == .failure(.invalidValue(part: part, value: value)))
    }

    @Test func encodesAsRawStringAndDecodesByParsing() throws {
        let rule = try RecurrenceRule.parse("DTSTART:20261001;FREQ=WEEKLY;INTERVAL=2;BYDAY=SA").get()

        let data = try JSONEncoder().encode([rule])
        #expect(String(decoding: data, as: UTF8.self) == #"["DTSTART:20261001;FREQ=WEEKLY;INTERVAL=2;BYDAY=SA"]"#)
        #expect(try JSONDecoder().decode([RecurrenceRule].self, from: data) == [rule])
        #expect(throws: DecodingError.self) {
            try JSONDecoder().decode([RecurrenceRule].self, from: Data(#"["FREQ=HOURLY"]"#.utf8))
        }
    }
}
