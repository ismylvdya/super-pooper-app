import Foundation
import Testing
@testable import SuperPooperApp

/// The morning review's Tomorrow: tomorrow as its turn will bring it, planned today.
@MainActor
struct TomorrowPlanTests {
    private let config: AppConfig

    init() throws {
        config = try AppConfig.load(bundle: .main)
    }

    private func plan(_ tasks: [TaskItem], ahead: DayState.Ahead) -> DayPlan {
        DayPlanning.tomorrow(config: config, settings: TestConfig.defaults, tasks: tasks, events: [], reminders: [], ahead: ahead,
                             sections: nil, context: TestCalendar.context(), eventsKnown: true)
    }

    /// Put off today, a task comes back tomorrow; kept out of tomorrow it does not; a habit skipped in tomorrow's plan
    /// does not either, and a task dated tomorrow comes.
    @Test func tomorrowHoldsWhatItsTurnBrings() {
        let tomorrow = LocalDate("2026-10-22")
        let putOff = makeTask("Put off", inPool: false)
        let keptOut = makeTask("Kept out", inPool: false) { $0.isNotTomorrow = true }
        let dated = makeTask("Dated", status: .someday) { $0.due = TaskDue(day: tomorrow) }
        let run = makeHabit("Run", status: .habit)
        let read = makeHabit("Read", status: .habit)
        var ahead = DayState.Ahead(day: tomorrow)
        ahead.skipped = ["Read"]
        let names = Set(plan([putOff, keptOut, dated, run, read], ahead: ahead).poolNames)
        #expect(names == ["Put off", "Dated", "Run"])
    }
}

struct EarlyDayTurnTests {
    private let rules = TestConfig.rules.day
    private let target = LocalDate("2026-10-22")

    private func context(_ date: LocalDate, _ time: String, boundary: String = "03:00") -> DayContext {
        let calendar = TestCalendar.calendar
        return DayContext(now: date.startDate(in: calendar, offset: LocalTime(time)), calendar: calendar,
                          boundary: LocalTime(boundary), energyHour: LocalTime("10:00"))
    }

    @Test func onlyFromEighteenToThree() {
        let evening = target.adding(days: -1)
        #expect(rules.earlyDayTurnTarget(in: context(evening, "17:59")) == nil)
        #expect(rules.earlyDayTurnTarget(in: context(evening, "18:00")) == target)
        #expect(rules.earlyDayTurnTarget(in: context(target, "02:59")) == target)
        #expect(rules.earlyDayTurnTarget(in: context(target, "03:00", boundary: "04:00")) == nil)
        #expect(rules.earlyDayTurnTarget(in: context(target, "02:59", boundary: "02:00")) == nil)
    }

    @Test func theNormalBoundaryDoesNotAdvanceTheDayTwice() {
        let before = context(target.adding(days: -1), "22:00")
        let early = before.advancingEarly(to: target)
        let atBoundary = context(target, "03:00").advancingEarly(to: target)
        #expect(early.now == before.now)
        #expect(early.today == target && early.focus == atBoundary.dayStart)
        #expect(early.dayEnd == atBoundary.dayEnd)
        #expect(rules.earlyDayTurnTarget(in: early) == nil)
        #expect(rules.earlyDayTurnTarget(in: context(target, "18:00").advancingEarly(to: target)) == target.adding(days: 1))
    }
}

/// The room of a dragged "+" among the review's rows.
struct ReviewGapRowsTests {
    @Test func theRoomStandsAfterTheRowBeforeItInItsGroup() {
        let rows: [ReviewGroups.Row] = [.header(.morning), .item("A"), .header(.day), .item("B"), .item("C"), .header(.evening)]
        #expect(ReviewGroups.rows(rows, gap: "+", order: ["A", "B", "+", "C"], in: .day)
                == [.header(.morning), .item("A"), .header(.day), .item("B"), .item("+"), .item("C"), .header(.evening)])
        #expect(ReviewGroups.rows(rows, gap: "+", order: ["A", "+", "B", "C"], in: .evening)
                == [.header(.morning), .item("A"), .header(.day), .item("B"), .item("C"), .header(.evening), .item("+")])
    }
}
