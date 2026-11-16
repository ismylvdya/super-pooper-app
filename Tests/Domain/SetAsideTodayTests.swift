import Foundation
import Testing
@testable import SuperPooperApp

/// The bottom of the morning review: what was taken out of today and can come back.
@Suite("Set aside today")
struct SetAsideTodayTests {
    private let today = LocalDate(TestCalendar.wednesday)
    @Test func putOffTasksAndSkippedHabits() {
        let putOff = makeTask("Call", inPool: false)
        let dated = makeTask("Pay") { $0.due = TaskDue(day: LocalDate(TestCalendar.wednesday)) }
        let datedPutOff = makeTask("Post", status: .someday, inPool: false) { $0.due = TaskDue(day: LocalDate(TestCalendar.wednesday)) }
        let skipped = makeHabit("Run", status: .habit)
        let kept = makeHabit("Tea", status: .habit)
        let later = makeTask("Paint", status: .someday)
        let found = SetAsideToday.notes(in: [putOff, dated, datedPutOff, skipped, kept, later], skipped: ["Run"], today: today, boundary: .midnight)
        #expect(found.map(\.name) == ["Call", "Post", "Run"], "one dated today in Someday, put off, can come back too")
    }

    @Test func aStepWaitingForAnEarlierOneIsNotPutOff() {
        let trip = makeTask("Trip") { $0.stepsOneByOne = true }
        let first = makeTask("Pack", inPool: false) {
            $0.projects = ["Trip"]
            $0.subtaskOrder = 0
        }
        let second = makeTask("Go", inPool: false) {
            $0.projects = ["Trip"]
            $0.subtaskOrder = 1
        }
        #expect(SetAsideToday.notes(in: [trip, first, second], skipped: [], today: today, boundary: .midnight).map(\.name) == ["Pack"])
    }
}

/// Tomorrow planned in today's review becomes tomorrow's state when it comes.
struct DayStateAheadTests {
    @Test func tomorrowsPlanBecomesItsState() {
        var state = DayState(day: LocalDate("2026-10-21"))
        var ahead = state.plan(of: LocalDate("2026-10-22"))
        ahead.skipped = ["Run"]
        ahead.manualOrder = ["B", "A"]
        ahead.reviewed = true
        state.ahead = ahead
        let next = state.rolled(to: LocalDate("2026-10-22"))
        #expect(next.skipped == ["Run"] && next.manualOrder == ["B", "A"] && next.reviewShown)
        #expect(state.rolled(to: LocalDate("2026-10-23")).skipped.isEmpty, "a plan of another day says nothing")
    }
}
