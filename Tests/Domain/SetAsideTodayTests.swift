import Foundation
import Testing
@testable import SuperPooperApp

/// The bottom of the morning review: what was taken out of today and can come back.
@Suite("Set aside today")
struct SetAsideTodayTests {
    @Test func putOffTasksAndSkippedHabits() {
        let putOff = makeTask("Call") { $0.waitsInList = true }
        let dated = makeTask("Pay") { $0.due = TaskDue(day: LocalDate(TestCalendar.wednesday)) }
        let skipped = makeHabit("Run", status: .habit)
        let kept = makeHabit("Tea", status: .habit)
        let later = makeTask("Paint", status: .someday)
        let found = SetAsideToday.notes(in: [putOff, dated, skipped, kept, later], skipped: ["Run"])
        #expect(found.map(\.name) == ["Call", "Run"])
    }

    @Test func aStepWaitingForAnEarlierOneIsNotPutOff() {
        let trip = makeTask("Trip") { $0.stepsOneByOne = true }
        let first = makeTask("Pack") {
            $0.projects = ["Trip"]
            $0.subtaskOrder = 0
            $0.waitsInList = true
        }
        let second = makeTask("Go") {
            $0.projects = ["Trip"]
            $0.subtaskOrder = 1
            $0.waitsInList = true
        }
        #expect(SetAsideToday.notes(in: [trip, first, second], skipped: []).map(\.name) == ["Pack"])
    }
}
