import CoreGraphics
import Testing
@testable import SuperPooperApp

/// "Pull for +4 weeks" (.28232): the weeks seen first stay put — the scroll moves down by exactly the rows added above
/// them, then runs up to the oldest added week. A grid row is a week known by its first day, so the old weeks keep their
/// rows when new ones come on top.
struct HabitHistoryPullTests {
    @Test func theAddedWeeksAreAsTallAsTheirRows() {
        let metrics = HabitDotMetrics.cell(30, ring: 2)
        #expect(metrics.height(ofWeeks: 4) == 4 * (metrics.cell + metrics.spacing))
        #expect(metrics.height(ofWeeks: 0) == 0)
    }

    @Test func aWeekKeepsItsIdentityWhenOlderWeeksAreAdded() {
        let today = LocalDate("2026-10-20")
        let habit = makeHabit("Water")
        let days = TestCalendar.days
        let before = HabitGrid(task: habit, weekCount: 5, today: today, days: days).weeks.map { $0.first?.date }
        let after = HabitGrid(task: habit, weekCount: 9, today: today, days: days).weeks.map { $0.first?.date }
        #expect(Array(after.suffix(5)) == before, "the weeks seen keep their first days, the new ones come on top")
    }
}
