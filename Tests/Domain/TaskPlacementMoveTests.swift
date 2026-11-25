import Foundation
import Testing
@testable import SuperPooperApp

/// What a task dragged onto a backlog page, or from one into a day, becomes (Wednesday 13:25).
struct TaskPlacementMoveTests {
    private let context = TestCalendar.context()
    private let wednesday = LocalDate(TestCalendar.wednesday)
    private var friday: LocalDate { wednesday.adding(days: 2) }

    @Test func fromAnotherDayIntoSoonTheDateGoes() {
        let task = makeTask("Pay") { $0.due = TaskDue(day: friday) }
        let outcome = TaskPlacementMove.changes(for: task, to: .list(.thisWeek), fromScheduled: false, context: context)
        #expect(outcome == [.due(nil), .inTodayPool(false)])
    }

    @Test func intoAnotherDaysPoolDatedThatDay() {
        let outcome = TaskPlacementMove.changes(for: makeTask("Read", status: .someday), to: .pool(friday, sectionTag: nil), fromScheduled: false, context: context)
        #expect(outcome == [.status(.thisWeek), .due(TaskDue(day: friday)), .inTodayPool(false)])
    }


    /// Into Next actions the date goes and the task waits there, out of the pool; into today's pool it takes the mark and
    /// keeps its date (a deadline), into another day's that day's date.
    @Test func theMarkPutsATaskInTodaysPool() {
        let dated = makeTask("Report") { $0.due = TaskDue(day: context.today) }
        #expect(TaskPlacementMove.changes(for: dated, to: .list(.thisWeek), fromScheduled: false, context: context) == [.due(nil), .inTodayPool(false)])
        let someday = makeTask("Trip", status: .someday) { $0.due = TaskDue(day: friday) }
        #expect(TaskPlacementMove.changes(for: someday, to: .pool(context.today, sectionTag: nil), fromScheduled: false, context: context) == [.status(.thisWeek), .inTodayPool(true)])
    }
}
