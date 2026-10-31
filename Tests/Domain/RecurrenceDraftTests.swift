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

    /// Parts the editor keeps without showing them come back as they were: the start's time, the end's time, the week
    /// start.
    @Test func hiddenPartsOfARuleAreWrittenBack() throws {
        let rule = try RecurrenceRule.parse("DTSTART:20261001T090000Z;FREQ=WEEKLY;INTERVAL=2;BYDAY=MO,TH;UNTIL=20261231T235900Z;WKST=SU").get()
        #expect(RecurrenceDraft.canEdit(rule, start: start))
        var draft = RecurrenceDraft(rule: rule, fallbackStart: start)
        draft.interval = 3
        let written = try RecurrenceRule.parse(draft.raw).get()
        #expect(written.startTime == LocalTime("09:00"))
        #expect(written.untilDate == LocalDate("2026-12-31") && written.untilTime == LocalTime("23:59"))
        #expect(written.weekStart == .sunday)
        #expect(written.interval == 3 && written.byDay == rule.byDay)
    }

    /// A rule with more than the editor shows is not edited (writing it back would lose those parts).
    @Test(arguments: [
        "DTSTART:20261001;FREQ=MONTHLY;BYMONTHDAY=1,15",
        "DTSTART:20261001;FREQ=MONTHLY;BYMONTHDAY=-2",
        "DTSTART:20261001;FREQ=MONTHLY;BYDAY=MO",
        "DTSTART:20261001;FREQ=MONTHLY;BYDAY=5FR",
        "DTSTART:20261001;FREQ=YEARLY;BYMONTH=1,6",
        "DTSTART:20261001;FREQ=YEARLY;BYMONTH=12;BYMONTHDAY=25",
        "DTSTART:20261001;FREQ=WEEKLY;BYDAY=2MO",
        "DTSTART:20261001;FREQ=DAILY;BYMONTH=6",
        "DTSTART:20261001;FREQ=DAILY;COUNT=3;UNTIL=20261231",
    ])
    func aRuleWithMoreThanTheEditorShowsIsNotEdited(raw: String) throws {
        #expect(!RecurrenceDraft.canEdit(try RecurrenceRule.parse(raw).get(), start: start))
    }

    @Test(arguments: [
        "DTSTART:20261001;FREQ=DAILY;INTERVAL=2",
        "DTSTART:20261001;FREQ=WEEKLY;BYDAY=MO,TH;COUNT=5",
        "FREQ=WEEKLY",
        "DTSTART:20261001;FREQ=MONTHLY;BYMONTHDAY=15",
        "DTSTART:20261001;FREQ=MONTHLY;BYMONTHDAY=-1",
        "DTSTART:20261001;FREQ=MONTHLY;BYDAY=-1FR",
        "DTSTART:20261001;FREQ=MONTHLY",
        "DTSTART:20261001;FREQ=YEARLY;BYMONTH=10;BYMONTHDAY=1",
        "DTSTART:20261001;FREQ=YEARLY",
    ])
    func aRuleTheEditorShowsWholeIsEdited(raw: String) throws {
        #expect(RecurrenceDraft.canEdit(try RecurrenceRule.parse(raw).get(), start: start))
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
