import Testing
@testable import SuperPooperApp

@Suite struct RecurrenceDraftTests {
    private let start = LocalDate(year: 2026, month: 10, day: 23)!

    private func roundTrip(_ draft: RecurrenceDraft) -> RecurrenceDraft? {
        guard case .success(let rule) = RecurrenceRule.parse(draft.raw) else { return nil }
        return RecurrenceDraft(rule: rule, fallbackStart: start)
    }

    @Test func dailyIsTheDefault() {
        #expect(RecurrenceDraft(start: start).raw == "DTSTART:20261023T000000Z;FREQ=DAILY")
    }

    @Test func weeklyWithoutDaysUsesTheStartWeekday() {
        var draft = RecurrenceDraft(start: start)
        draft.frequency = .weekly
        #expect(draft.raw.hasSuffix("FREQ=WEEKLY;BYDAY=FR"))
    }

    @Test func everyOtherWeekOnTwoDaysEndingByCount() {
        var draft = RecurrenceDraft(start: start)
        draft.frequency = .weekly
        draft.interval = 2
        draft.weekdays = [.thursday, .monday]
        draft.end = .count(5)
        #expect(draft.raw == "DTSTART:20261023T000000Z;FREQ=WEEKLY;INTERVAL=2;BYDAY=MO,TH;COUNT=5")
        #expect(roundTrip(draft) == draft)
    }

    @Test(arguments: [
        RecurrenceDraft.MonthlyDay.dayOfMonth(15), .lastDayOfMonth, .weekday(ordinal: 2, weekday: .tuesday), .weekday(ordinal: -1, weekday: .friday),
    ])
    func monthlyShapesSurviveAParseRoundTrip(day: RecurrenceDraft.MonthlyDay) {
        var draft = RecurrenceDraft(start: start)
        draft.frequency = .monthly
        draft.monthlyDay = day
        draft.end = .until(LocalDate(year: 2027, month: 1, day: 31)!)
        #expect(roundTrip(draft) == draft)
    }

    @Test func yearlyPinsMonthAndDay() {
        var draft = RecurrenceDraft(start: start)
        draft.frequency = .yearly
        #expect(draft.raw.hasSuffix("FREQ=YEARLY;BYMONTH=10;BYMONTHDAY=23"))
    }

    @Test func builtRulesOccurOnTheRightDays() throws {
        var draft = RecurrenceDraft(start: start)
        draft.frequency = .weekly
        draft.weekdays = [.thursday]
        guard case .success(let rule) = RecurrenceRule.parse(draft.raw) else {
            Issue.record("parse failed")
            return
        }
        let schedule = RecurrenceSchedule(rule: rule, fallbackStart: start)
        #expect(schedule.occurs(on: LocalDate(year: 2026, month: 10, day: 29)!))
        #expect(!schedule.occurs(on: LocalDate(year: 2026, month: 10, day: 30)!))
    }
}
