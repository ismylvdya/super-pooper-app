import Foundation
import Testing
@testable import SuperPooper

/// The date chip of a task counts logical days, like the Today / Tomorrow chips.
@MainActor
struct DueTextTests {
    private let context = TestCalendar.context(TestCalendar.wednesday, "23:00")

    @Test func afterMidnightBeforeTheBoundaryIsStillTonight() {
        #expect(DueText.format(TaskDue("2026-10-22T01:00"), context: context) == "01:00")
        #expect(DueText.format(TaskDue("2026-10-22T09:00"), context: context) == L10n.format("due.dayAndTime", L10n.string("due.tomorrow"), "09:00"))
        #expect(DueText.format(TaskDue("2026-10-21"), context: context) == L10n.string("due.today"))
    }
}
