import Foundation
import Testing
@testable import SuperPooperApp

/// A repeat rule with no start in the note (no DTSTART, `due` or `date_created`, as a hand-written note can be): its
/// days are counted from one fixed day, so it keeps its own days instead of matching every day it is asked about.
@Suite("Repeat rules without a start")
struct UndatedRecurrenceTests {
    private func undated(_ rule: String) -> TaskItem {
        makeHabit("Undated", rule: rule, status: .habit) { task in
            task.created = nil
            task.dateCreated = nil
            task.due = nil
        }
    }

    private let occurrence = TaskOccurrence(days: TestCalendar.days)

    /// Weekly without BYDAY is the start's weekday: one day a week, not all seven.
    @Test func aWeeklyRuleKeepsOneDayAWeek() {
        let habit = undated("FREQ=WEEKLY")
        let week = (0..<7).map { LocalDate("2026-10-19").adding(days: $0) }
        let days = week.filter { occurrence.occurs(habit, on: $0) }
        #expect(days.count == 1)
        #expect(days.first?.weekday == TaskOccurrence.undatedStart.weekday)
    }

    @Test func anIntervalRuleSkipsTheDaysBetween() {
        let habit = undated("FREQ=DAILY;INTERVAL=3")
        let days = (0..<9).map { LocalDate("2026-10-19").adding(days: $0) }.filter { occurrence.occurs(habit, on: $0) }
        #expect(days.count == 3)
    }

    /// COUNT is used up long before today when counted from the fixed day.
    @Test func aCountRuleDoesNotStartAgainEveryDay() {
        let habit = undated("FREQ=DAILY;COUNT=3")
        #expect(!occurrence.occurs(habit, on: LocalDate(TestCalendar.wednesday)))
    }

    /// A daily rule does not depend on its start: still every day.
    @Test func aDailyRuleIsStillEveryDay() {
        let habit = undated("FREQ=DAILY")
        #expect(occurrence.occurs(habit, on: LocalDate(TestCalendar.wednesday)))
    }

    @Test func theNoteIsMarkedAsAProblem() {
        let plan = DayScenario(tasks: [undated("FREQ=WEEKLY"), makeHabit("Dated", status: .habit)]).build()
        #expect(plan.problems(of: "Undated") == [.recurrenceWithoutStart])
        #expect(plan.problems(of: "Dated").isEmpty)
    }

    /// One schedule per task answers for every day of a long history (a COUNT rule lists its days once).
    @Test func oneScheduleAnswersLikeTheOccurrence() {
        let habit = makeHabit("Counted", rule: "DTSTART:20260901;FREQ=WEEKLY;BYDAY=MO,TH;COUNT=20", status: .habit)
        let schedule = occurrence.schedule(of: habit)
        for offset in 0..<120 {
            let day = LocalDate("2026-09-01").adding(days: offset)
            #expect(schedule.occurs(on: day) == occurrence.occurs(habit, on: day))
        }
    }
}
