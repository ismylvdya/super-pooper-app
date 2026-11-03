import Foundation
import Testing
@testable import SuperPooperApp

/// What a task dragged onto a backlog page, or from one into a day, becomes (Wednesday 13:25).
struct BacklogMovesTests {
    private let context = TestCalendar.context()
    private let wednesday = LocalDate(TestCalendar.wednesday)
    private var friday: LocalDate { wednesday.adding(days: 2) }

    @Test func fromTodayIntoSoonIsNotToday() {
        let outcome = BacklogMoves.onto(.thisWeek, task: makeTask("Pay"), fromShownDay: true, shown: wednesday, context: context)
        #expect(outcome == BacklogMoves.Outcome(isNotToday: true))
    }

    @Test func fromAnotherDayIntoSoonTheDateGoes() {
        let task = makeTask("Pay") { $0.due = TaskDue(day: friday) }
        let outcome = BacklogMoves.onto(.thisWeek, task: task, fromShownDay: true, shown: friday, context: context)
        #expect(outcome == BacklogMoves.Outcome(edits: [.due(nil)]))
    }

    /// From a later level into Soon on today's page: this week's, and kept out of today's pool, where it would land
    /// otherwise; one dated later needs no keeping out, and on another day's page nothing is kept out.
    @Test func fromALaterLevelIntoSoonItWaitsThere() {
        let someday = makeTask("Read", status: .someday)
        let onToday = BacklogMoves.onto(.thisWeek, task: someday, fromShownDay: false, shown: wednesday, context: context)
        #expect(onToday == BacklogMoves.Outcome(edits: [.status(.thisWeek)], postpones: true))
        let dated = makeTask("Read", status: .someday) { $0.due = TaskDue(day: friday) }
        #expect(!BacklogMoves.onto(.thisWeek, task: dated, fromShownDay: false, shown: wednesday, context: context).postpones)
        #expect(!BacklogMoves.onto(.thisWeek, task: someday, fromShownDay: false, shown: friday, context: context).postpones)
    }

    @Test func ontoALaterLevelItTakesThatLevel() {
        let outcome = BacklogMoves.onto(.someday, task: makeTask("Pay"), fromShownDay: true, shown: wednesday, context: context)
        #expect(outcome == BacklogMoves.Outcome(edits: [.status(.someday)], unpostpones: true))
        let started = makeTask("Pay", status: .inProgress)
        #expect(BacklogMoves.onto(.thisWeek, task: started, fromShownDay: false, shown: friday, context: context).edits.isEmpty,
                "a started task already is this week's")
    }

    @Test func intoTodaysPoolUndatedAndBack() {
        let dated = makeTask("Read", status: .halfYear) { $0.due = TaskDue(day: friday) }
        #expect(BacklogMoves.intoPool(dated, day: wednesday, context: context)
            == BacklogMoves.Outcome(edits: [.status(.thisWeek), .due(nil)], unpostpones: true))
        let today = makeTask("Pay") { $0.due = TaskDue(day: wednesday) }
        #expect(BacklogMoves.intoPool(today, day: wednesday, context: context).edits.isEmpty, "already today's")
    }

    @Test func intoAnotherDaysPoolDatedThatDay() {
        let outcome = BacklogMoves.intoPool(makeTask("Read", status: .someday), day: friday, context: context)
        #expect(outcome == BacklogMoves.Outcome(edits: [.status(.thisWeek), .due(TaskDue(day: friday))]))
    }

    @Test func ontoTheTimelineAtTheDroppedTime() {
        let moment = TestCalendar.date(TestCalendar.wednesday, "15:30")
        let outcome = BacklogMoves.ontoTimeline(makeTask("Read", status: .someday), at: moment, context: context)
        #expect(outcome.edits == [.status(.thisWeek), .due(TaskDue(day: wednesday, time: LocalTime("15:30")))])
        #expect(outcome.unpostpones)
    }
}
