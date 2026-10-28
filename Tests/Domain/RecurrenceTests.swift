import Foundation
import Testing
@testable import SuperPooperApp

private func day(_ iso: String) -> LocalDate {
    guard let value = LocalDate(isoString: iso) else { preconditionFailure("Invalid fixture date \(iso)") }
    return value
}

private func schedule(_ raw: String, fallback: String = "2026-01-01") throws -> RecurrenceSchedule {
    RecurrenceSchedule(rule: try RecurrenceRule.parse(raw).get(), fallbackStart: day(fallback))
}

private func occurrences(
    _ raw: String,
    from start: String,
    through end: String,
    fallback: String = "2026-01-01"
) throws -> [String] {
    try schedule(raw, fallback: fallback).occurrences(from: day(start), through: day(end)).map(\.isoString)
}

@Suite("Recurrence schedule")
struct RecurrenceScheduleTests {
    // MARK: - Daily

    @Test func dailyRuleOccursEveryDayFromStart() throws {
        let raw = "DTSTART:20261001T090000Z;FREQ=DAILY"
        let daily = try schedule(raw)

        #expect(try occurrences(raw, from: "2026-09-28", through: "2026-10-03") == ["2026-10-01", "2026-10-02", "2026-10-03"])
        #expect(!daily.occurs(on: day("2026-09-30")))
        #expect(daily.occurs(on: day("2031-05-05")))
    }

    @Test(arguments: [
        "DTSTART:20261001;FREQ=DAILY",
        "DTSTART:20261001;FREQ=WEEKLY;BYDAY=MO,TU,WE,TH,FR,SA,SU",
        "DTSTART:20261015;FREQ=MONTHLY;BYMONTHDAY=1,-1",
        "DTSTART:20261001;FREQ=YEARLY;BYMONTH=1,9;BYDAY=MO",
        "DTSTART:20261001;FREQ=DAILY;COUNT=5",
    ])
    func daysBeforeStartNeverOccur(raw: String) throws {
        let rule = try schedule(raw, fallback: "2020-01-01")

        #expect(rule.occurrences(from: day("2020-01-01"), through: day("2026-09-30")).isEmpty)
        #expect(!rule.occurs(on: day("2026-09-30")))
        #expect(rule.nextOccurrence(onOrAfter: day("2020-01-01")).map { $0 >= day("2026-10-01") } == true)
    }

    @Test func dailyIntervalCountsDaysFromStart() throws {
        let raw = "DTSTART:20261001;FREQ=DAILY;INTERVAL=3"
        let everyThirdDay = try schedule(raw)

        #expect(try occurrences(raw, from: "2026-10-01", through: "2026-10-12")
            == ["2026-10-01", "2026-10-04", "2026-10-07", "2026-10-10"])
        #expect(everyThirdDay.occurs(on: day("2026-12-30")))
        #expect(!everyThirdDay.occurs(on: day("2026-12-31")))
    }

    @Test func dailyByDayAndByMonthActAsFilters() throws {
        #expect(try occurrences(
            "DTSTART:20261001;FREQ=DAILY;BYDAY=MO,WE,FR;BYMONTH=10",
            from: "2026-10-01", through: "2026-11-30"
        ) == [
            "2026-10-02", "2026-10-05", "2026-10-07", "2026-10-09", "2026-10-12", "2026-10-14", "2026-10-16",
            "2026-10-19", "2026-10-21", "2026-10-23", "2026-10-26", "2026-10-28", "2026-10-30",
        ])
    }

    // MARK: - Weekly

    @Test func weeklyWithoutByDayRepeatsStartWeekday() throws {
        #expect(try occurrences("DTSTART:20261001;FREQ=WEEKLY", from: "2026-09-01", through: "2026-10-31")
            == ["2026-10-01", "2026-10-08", "2026-10-15", "2026-10-22", "2026-10-29"])
    }

    @Test func weeklyByDayIncludesOnlyListedWeekdays() throws {
        #expect(try occurrences("DTSTART:20261001;FREQ=WEEKLY;BYDAY=MO,TH", from: "2026-09-28", through: "2026-10-13")
            == ["2026-10-01", "2026-10-05", "2026-10-08", "2026-10-12"])
    }

    @Test func biweeklySaturdayWrittenByTaskNotes() throws {
        #expect(try occurrences(
            "DTSTART:20261001;FREQ=WEEKLY;INTERVAL=2;BYDAY=SA",
            from: "2026-10-01", through: "2026-11-15"
        ) == ["2026-10-03", "2026-10-17", "2026-10-31", "2026-11-14"])
    }

    @Test(arguments: [
        ("", ["2026-10-04", "2026-10-12", "2026-10-18", "2026-10-26", "2026-11-01"]),
        (";WKST=SU", ["2026-10-04", "2026-10-05", "2026-10-18", "2026-10-19", "2026-11-01"]),
    ])
    func biweeklyWeeksAlignToWeekStart(weekStart: String, expected: [String]) throws {
        #expect(try occurrences(
            "DTSTART:20261004;FREQ=WEEKLY;INTERVAL=2;BYDAY=MO,SU" + weekStart,
            from: "2026-09-01", through: "2026-11-01"
        ) == expected)
    }

    // MARK: - Monthly

    @Test(arguments: ["DTSTART:20260131;FREQ=MONTHLY;BYMONTHDAY=31", "DTSTART:20260131;FREQ=MONTHLY"])
    func monthlyOn31stSkipsShorterMonths(raw: String) throws {
        #expect(try occurrences(raw, from: "2026-01-01", through: "2026-12-31") == [
            "2026-01-31", "2026-03-31", "2026-05-31", "2026-07-31", "2026-08-31", "2026-10-31", "2026-12-31",
        ])
    }

    @Test func monthlyNegativeMonthDayCountsFromMonthEnd() throws {
        let raw = "DTSTART:20260115;FREQ=MONTHLY;BYMONTHDAY=-1"
        let lastDay = try schedule(raw)

        #expect(try occurrences(raw, from: "2026-01-01", through: "2026-06-30")
            == ["2026-01-31", "2026-02-28", "2026-03-31", "2026-04-30", "2026-05-31", "2026-06-30"])
        #expect(lastDay.occurs(on: day("2028-02-29")))
        #expect(!lastDay.occurs(on: day("2028-02-28")))
    }

    @Test func monthlyOrdinalWeekdayPicksSecondMonday() throws {
        #expect(try occurrences("DTSTART:20261001;FREQ=MONTHLY;BYDAY=2MO", from: "2026-10-01", through: "2027-01-31")
            == ["2026-10-12", "2026-11-09", "2026-12-14", "2027-01-11"])
    }

    @Test func monthlyNegativeOrdinalPicksLastFriday() throws {
        #expect(try occurrences("DTSTART:20261001;FREQ=MONTHLY;BYDAY=-1FR", from: "2026-10-01", through: "2027-01-31")
            == ["2026-10-30", "2026-11-27", "2026-12-25", "2027-01-29"])
    }

    @Test func monthlyPlainByDayMeansEveryMatchingWeekdayOfActiveMonths() throws {
        #expect(try occurrences(
            "DTSTART:20261001;FREQ=MONTHLY;INTERVAL=2;BYDAY=TU",
            from: "2026-10-01", through: "2026-12-31"
        ) == ["2026-10-06", "2026-10-13", "2026-10-20", "2026-10-27", "2026-12-01", "2026-12-08", "2026-12-15", "2026-12-22", "2026-12-29"])
    }

    @Test func monthDayAndWeekdayMustBothMatch() throws {
        #expect(try occurrences(
            "DTSTART:20260101;FREQ=MONTHLY;BYDAY=FR;BYMONTHDAY=13",
            from: "2026-01-01", through: "2027-12-31"
        ) == ["2026-02-13", "2026-03-13", "2026-11-13", "2027-08-13"])
    }

    // MARK: - Yearly

    @Test func yearlyByMonthAndMonthDay() throws {
        #expect(try occurrences("DTSTART:20260101;FREQ=YEARLY;BYMONTH=3;BYMONTHDAY=8", from: "2026-01-01", through: "2028-12-31")
            == ["2026-03-08", "2027-03-08", "2028-03-08"])
    }

    @Test func yearlyByMonthWithoutDayUsesStartDayAndSkipsStartItself() throws {
        #expect(try occurrences("DTSTART:20260310;FREQ=YEARLY;BYMONTH=6,9", from: "2026-01-01", through: "2027-12-31")
            == ["2026-06-10", "2026-09-10", "2027-06-10", "2027-09-10"])
    }

    @Test func yearlyFromFebruary29OccursOnlyInLeapYears() throws {
        let raw = "DTSTART:20240229;FREQ=YEARLY"
        let leapDay = try schedule(raw)

        #expect(try occurrences(raw, from: "2024-01-01", through: "2032-12-31") == ["2024-02-29", "2028-02-29", "2032-02-29"])
        #expect(leapDay.nextOccurrence(onOrAfter: day("2024-03-01")) == day("2028-02-29"))
    }

    @Test func yearlyOrdinalWeekdayWithinByMonth() throws {
        #expect(try occurrences("DTSTART:20260101;FREQ=YEARLY;BYMONTH=11;BYDAY=4TH", from: "2026-01-01", through: "2027-12-31")
            == ["2026-11-26", "2027-11-25"])
    }

    @Test func yearlyOrdinalWeekdayWithoutByMonthCountsWithinYear() throws {
        #expect(try occurrences("DTSTART:20260101;FREQ=YEARLY;BYDAY=1MO,-1FR", from: "2026-01-01", through: "2027-12-31")
            == ["2026-01-05", "2026-12-25", "2027-01-04", "2027-12-31"])
    }

    /// rrule.js only defaults BYMONTH when no day filter is given, so this repeats every month.
    @Test func yearlyByMonthDayWithoutByMonthMatchesEveryMonth() throws {
        #expect(try occurrences("DTSTART:20261001;FREQ=YEARLY;BYMONTHDAY=15", from: "2026-10-01", through: "2027-01-31")
            == ["2026-10-15", "2026-11-15", "2026-12-15", "2027-01-15"])
    }

    // MARK: - COUNT

    @Test func countStartsWithFirstMatchingDayNotDtstart() throws {
        let raw = "DTSTART:20261001;FREQ=WEEKLY;BYDAY=MO;COUNT=3"
        let threeMondays = try schedule(raw)

        #expect(try occurrences(raw, from: "2026-09-01", through: "2026-12-31") == ["2026-10-05", "2026-10-12", "2026-10-19"])
        #expect(!threeMondays.occurs(on: day("2026-10-01")))
        #expect(!threeMondays.occurs(on: day("2026-10-26")))
        #expect(threeMondays.nextOccurrence(onOrAfter: day("2026-10-20")) == nil)
    }

    @Test func countIncludesOccurrencesBeforeRequestedRange() throws {
        let raw = "DTSTART:20261001T090000Z;FREQ=DAILY;INTERVAL=2;COUNT=3"

        #expect(try occurrences(raw, from: "2026-10-01", through: "2026-12-31") == ["2026-10-01", "2026-10-03", "2026-10-05"])
        #expect(try occurrences(raw, from: "2026-10-04", through: "2026-12-31") == ["2026-10-05"])
        #expect(try occurrences(raw, from: "2026-10-06", through: "2026-10-01").isEmpty)
    }

    @Test func countAndUntilBothLimitTheSeries() throws {
        #expect(try occurrences("DTSTART:20261001;FREQ=DAILY;COUNT=10;UNTIL=20261003", from: "2026-10-01", through: "2026-12-31")
            == ["2026-10-01", "2026-10-02", "2026-10-03"])
        #expect(try occurrences("DTSTART:20261001;FREQ=DAILY;COUNT=2;UNTIL=20261003", from: "2026-10-01", through: "2026-12-31")
            == ["2026-10-01", "2026-10-02"])
    }

    // MARK: - UNTIL

    @Test(arguments: [
        ("DTSTART:20261001;FREQ=DAILY;UNTIL=20261005", "2026-10-05"),
        ("FREQ=DAILY;UNTIL=20261005", "2026-10-05"),
        ("DTSTART:20261001;FREQ=DAILY;UNTIL=20261005T000000Z", "2026-10-05"),
        ("DTSTART:20261001T000000Z;FREQ=DAILY;UNTIL=20261005", "2026-10-05"),
        // rrule.js reads a date-only UNTIL as midnight, so a timed start loses the UNTIL day.
        ("DTSTART:20261001T090000Z;FREQ=DAILY;UNTIL=20261005", "2026-10-04"),
        ("DTSTART:20261001T090000Z;FREQ=DAILY;UNTIL=20261005T090000Z", "2026-10-05"),
        ("DTSTART:20261001T090000Z;FREQ=DAILY;UNTIL=20261005T085959Z", "2026-10-04"),
        ("DTSTART:20261001T090000Z;FREQ=DAILY;UNTIL=20261005T235959Z", "2026-10-05"),
    ])
    func untilComparesOccurrenceDateTime(raw: String, lastDay: String) throws {
        let bounded = try schedule(raw, fallback: "2026-10-01")
        let days = bounded.occurrences(from: day("2026-09-01"), through: day("2026-12-31")).map(\.isoString)

        #expect(days.first == "2026-10-01")
        #expect(days.last == lastDay)
        #expect(!bounded.occurs(on: day(lastDay).adding(days: 1)))
        #expect(bounded.nextOccurrence(onOrAfter: day(lastDay).adding(days: 1)) == nil)
    }

    // MARK: - Missing DTSTART

    @Test func missingDtstartAnchorsOnFallbackStart() throws {
        let weekly = try schedule("FREQ=WEEKLY", fallback: "2026-10-01")

        #expect(weekly.anchor == day("2026-10-01"))
        #expect(try occurrences("FREQ=WEEKLY", from: "2026-09-01", through: "2026-10-20", fallback: "2026-10-01")
            == ["2026-10-01", "2026-10-08", "2026-10-15"])
        #expect(try occurrences("FREQ=DAILY;INTERVAL=3", from: "2026-09-01", through: "2026-10-10", fallback: "2026-10-01")
            == ["2026-10-01", "2026-10-04", "2026-10-07", "2026-10-10"])
    }

    @Test func dtstartTakesPrecedenceOverFallback() throws {
        let daily = try schedule("DTSTART:20261005;FREQ=DAILY", fallback: "2026-10-01")

        #expect(daily.anchor == day("2026-10-05"))
        #expect(!daily.occurs(on: day("2026-10-03")))
        #expect(daily.occurs(on: day("2026-10-05")))
    }

    // MARK: - Queries

    @Test func occurrencesRangeIsInclusiveAndEmptyWhenReversed() throws {
        let daily = try schedule("DTSTART:20261001;FREQ=DAILY")

        #expect(daily.occurrences(from: day("2026-10-10"), through: day("2026-10-10")) == [day("2026-10-10")])
        #expect(daily.occurrences(from: day("2026-10-11"), through: day("2026-10-10")).isEmpty)
    }

    @Test func nextOccurrenceIsInclusiveAndStartsAtAnchor() throws {
        let mondays = try schedule("DTSTART:20261001;FREQ=WEEKLY;BYDAY=MO;UNTIL=20261231")

        #expect(mondays.nextOccurrence(onOrAfter: day("2026-01-01")) == day("2026-10-05"))
        #expect(mondays.nextOccurrence(onOrAfter: day("2026-10-12")) == day("2026-10-12"))
        #expect(mondays.nextOccurrence(onOrAfter: day("2026-10-13")) == day("2026-10-19"))
        #expect(mondays.nextOccurrence(onOrAfter: day("2026-12-29")) == nil)
    }

    @Test func nextOccurrenceReachesDistantYears() throws {
        let everyElevenYears = try schedule("DTSTART:20260101;FREQ=YEARLY;INTERVAL=11")

        #expect(everyElevenYears.nextOccurrence(onOrAfter: day("2026-01-02")) == day("2037-01-01"))
    }

    @Test func ruleThatNeverMatchesHasNoOccurrences() throws {
        let impossible = try schedule("DTSTART:20260101;FREQ=YEARLY;BYMONTH=2;BYMONTHDAY=30;COUNT=3")

        #expect(impossible.nextOccurrence(onOrAfter: day("2026-01-01")) == nil)
        #expect(impossible.occurrences(from: day("2026-01-01"), through: day("2036-12-31")).isEmpty)
    }

    @Test(arguments: [
        "DTSTART:20261001;FREQ=WEEKLY;INTERVAL=3;BYDAY=TU,SA;WKST=SU",
        "DTSTART:20260131;FREQ=MONTHLY;INTERVAL=2;BYMONTHDAY=-1,15",
        "DTSTART:20261001;FREQ=MONTHLY;BYDAY=1MO,-2WE;COUNT=7",
        "DTSTART:20260101;FREQ=YEARLY;BYMONTH=2,8;BYDAY=-1SU,2TH;UNTIL=20271015",
        "DTSTART:20261001T090000Z;FREQ=DAILY;INTERVAL=4;BYMONTH=10,11;COUNT=12",
    ])
    func occursAgreesWithOccurrences(raw: String) throws {
        let rule = try schedule(raw)
        let start = day("2026-01-01")
        let end = day("2027-12-31")
        let listed = Set(rule.occurrences(from: start, through: end))

        #expect(!listed.isEmpty)
        for offset in 0...start.days(until: end) {
            let candidate = start.adding(days: offset)
            #expect(rule.occurs(on: candidate) == listed.contains(candidate), "\(candidate)")
        }
    }
}
