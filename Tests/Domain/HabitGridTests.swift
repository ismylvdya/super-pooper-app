import Foundation
import Testing
@testable import SuperPooper

/// The habit grid widget: weeks as columns ending with the current week, marks per day.
struct HabitGridTests {
    private let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Belgrade") ?? .current
        return calendar
    }()

    /// Wednesday.
    private let today = LocalDate(year: 2026, month: 10, day: 21)!

    private func habit(_ rule: String, complete: [Int] = [], partial: [Int] = [], twice: [Int] = []) -> TaskNote {
        var task = TaskNote(name: "Habit", relativePath: "Habit.md", status: .halfYear)
        task.recurrenceRaw = rule
        task.recurrence = try? RecurrenceRule.parse(rule).get()
        task.completeInstances = (complete + partial + twice).map { today.adding(days: $0) }
        task.partialInstances = partial.map { today.adding(days: $0) }
        task.twiceInstances = twice.map { today.adding(days: $0) }
        return task
    }

    @Test func layoutEndsWithCurrentWeekMondayFirst() {
        let grid = HabitGrid(task: habit("DTSTART:20260101;FREQ=DAILY"), weekCount: 3, today: today, calendar: calendar)
        #expect(grid.weeks.count == 3)
        #expect(grid.weeks.allSatisfy { $0.count == 7 })
        let current = grid.weeks[2]
        #expect(current[2] == .open)            // Wednesday = today
        #expect(current[3] == .future)          // Thursday
        #expect(current[6] == .future)          // Sunday
    }

    @Test func marksAreDistinct() {
        let grid = HabitGrid(task: habit("DTSTART:20260101;FREQ=DAILY", complete: [-1], partial: [-2], twice: [0]),
                             weekCount: 1, today: today, calendar: calendar)
        #expect(grid.weeks[0][0] == .partial)   // Monday
        #expect(grid.weeks[0][1] == .done)      // Tuesday
        #expect(grid.weeks[0][2] == .twice)     // Wednesday
    }

    @Test func daysWithoutInstanceAreNotScheduled() {
        let grid = HabitGrid(task: habit("DTSTART:20260101;FREQ=WEEKLY;BYDAY=MO"), weekCount: 1, today: today, calendar: calendar)
        #expect(grid.weeks[0][0] == .open)
        #expect(grid.weeks[0][1] == .notScheduled)
    }
}
