import Foundation
import Testing
@testable import SuperPooperApp

/// Monthly repeats as in Apple Calendar: "Each" day number, or "On the" first … last day or weekday.
struct MonthlyPatternTests {
    private let start = LocalDate(isoString: "2026-10-14")!

    private func monthly(_ edit: (inout RecurrenceDraft) -> Void) -> RecurrenceDraft {
        var draft = RecurrenceDraft(start: start)
        draft.frequency = .monthly
        edit(&draft)
        return draft
    }

    @Test func onTheWritesDaysAndWeekdaysOfTheMonth() {
        let secondMonday = monthly { $0.setMonthlyMode(.onThe); $0.monthlyPattern = MonthlyPattern(ordinal: .second, kind: .weekday(.monday)) }
        #expect(secondMonday.raw.hasSuffix("FREQ=MONTHLY;BYDAY=2MO"))
        let lastFriday = monthly { $0.setMonthlyMode(.onThe); $0.monthlyPattern = MonthlyPattern(ordinal: .last, kind: .weekday(.friday)) }
        #expect(lastFriday.raw.hasSuffix("BYDAY=-1FR"))
        let lastDay = monthly { $0.setMonthlyMode(.onThe); $0.monthlyPattern = MonthlyPattern(ordinal: .last, kind: .day) }
        #expect(lastDay.raw.hasSuffix("BYMONTHDAY=-1"))
        let firstDay = monthly { $0.setMonthlyMode(.onThe) }
        #expect(firstDay.raw.hasSuffix("BYMONTHDAY=1"))
    }

    /// "Each" starts at the start's day number, not at "the second Wednesday" of the start date.
    @Test func eachUsesTheDayNumber() {
        let each = monthly { _ in }
        #expect(each.monthlyMode == .each)
        #expect(each.raw.hasSuffix("BYMONTHDAY=14"))
    }

    @Test func rulesReadBackIntoTheirMode() throws {
        func draft(_ raw: String) throws -> RecurrenceDraft {
            guard case .success(let rule) = RecurrenceRule.parse(raw) else { throw RecurrenceParseError.empty }
            return RecurrenceDraft(rule: rule, fallbackStart: start)
        }
        #expect(try draft("FREQ=MONTHLY;BYMONTHDAY=15").monthlyMode == .each)
        let lastFriday = try draft("FREQ=MONTHLY;BYDAY=-1FR")
        #expect(lastFriday.monthlyMode == .onThe)
        #expect(lastFriday.monthlyPattern == MonthlyPattern(ordinal: .last, kind: .weekday(.friday)))
        #expect(try draft("FREQ=MONTHLY;BYMONTHDAY=-1").monthlyPattern == MonthlyPattern(ordinal: .last, kind: .day))
        #expect(try draft("FREQ=MONTHLY;BYMONTHDAY=1").monthlyMode == .onThe)
    }
}
