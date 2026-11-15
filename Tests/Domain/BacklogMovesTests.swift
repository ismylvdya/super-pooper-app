import Foundation
import Testing
@testable import SuperPooperApp

/// What a task dragged onto a backlog page, or from one into a day, becomes (Wednesday 13:25).
struct BacklogMovesTests {
    private let context = TestCalendar.context()
    private let wednesday = LocalDate(TestCalendar.wednesday)
    private var friday: LocalDate { wednesday.adding(days: 2) }

    @Test func fromAnotherDayIntoSoonTheDateGoes() {
        let task = makeTask("Pay") { $0.due = TaskDue(day: friday) }
        let outcome = BacklogMoves.onto(.thisWeek, task: task, fromShownDay: true, shown: friday, context: context)
        #expect(outcome == BacklogMoves.Outcome(edits: [.due(nil), .inTodayPool(false)]))
    }

    @Test func intoAnotherDaysPoolDatedThatDay() {
        let outcome = BacklogMoves.intoPool(makeTask("Read", status: .someday), day: friday, context: context)
        #expect(outcome == BacklogMoves.Outcome(edits: [.status(.thisWeek), .due(TaskDue(day: friday))]))
    }


    /// Into Next actions the date goes and the task waits there, out of the pool; into today's pool it takes the mark and
    /// keeps its date (a deadline), into another day's that day's date.
    @Test func theMarkPutsATaskInTodaysPool() {
        let dated = makeTask("Report") { $0.due = TaskDue(day: context.today) }
        #expect(BacklogMoves.onto(.thisWeek, task: dated, fromShownDay: true, shown: context.today, context: context).edits == [.due(nil), .inTodayPool(false)])
        let someday = makeTask("Trip", status: .someday) { $0.due = TaskDue(day: friday) }
        #expect(BacklogMoves.intoPool(someday, day: context.today, context: context).edits == [.status(.thisWeek), .inTodayPool(true)])
    }
}
