import Foundation
import Testing
@testable import SuperPooperApp

/// Left open past its time, a habit's or timed task's notification comes again every few minutes, the next few planned
/// ahead, each in place of the one before; nothing past the end of the day.
@Suite("Overdue repeats")
struct OverdueRepeatsTests {
    private let context = TestCalendar.context(TestCalendar.wednesday, "09:25")

    private func notification(at time: String, kind: PlannedNotification.Kind = .habit) -> PlannedNotification {
        PlannedNotification(id: "habit|Vitamins|09:00", kind: kind, title: "Vitamins",
                            fireDate: TestCalendar.date(TestCalendar.wednesday, time), taskName: "Vitamins",
                            day: LocalDate(TestCalendar.wednesday), key: "habit|Vitamins|09:00")
    }

    @Test func theNextOnesComeEveryTenMinutesFromNow() {
        let again = OverdueRepeats.notifications([notification(at: "09:00")], minutes: 10, count: 3, context: context)
        #expect(again.map { clockTime($0.fireDate) } == ["09:30", "09:40", "09:50"])
        #expect(again.map(\.key) == Array(repeating: "habit|Vitamins|09:00", count: 3))
        #expect(Set(again.map(\.id)).count == 3)
    }

    @Test func nothingYetDueIsRepeated() {
        #expect(OverdueRepeats.notifications([notification(at: "10:00")], minutes: 10, count: 3, context: context).isEmpty)
    }

    @Test func theRoundIsReadBackFromTheIdentifier() {
        #expect(NotificationIdentifier.round("sp|again|task|Call @ Anna|2026-10-21|4@1729500000") == 4)
        #expect(NotificationIdentifier.round("sp|habit|Vitamins|09:00") == 0)
    }
}
