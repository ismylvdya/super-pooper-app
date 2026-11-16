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

/// Tomorrow is offered in the evening only, and in the night that still belongs to the day.
struct TomorrowReviewOfferTests {
    @Test func onlyFromTheEvening() {
        let rules = TestConfig.rules.day
        let boundary = LocalTime("04:00")
        #expect(!rules.offersTomorrowReview(at: LocalTime("17:59"), boundary: boundary))
        #expect(rules.offersTomorrowReview(at: LocalTime("18:00"), boundary: boundary))
        #expect(rules.offersTomorrowReview(at: LocalTime("01:30"), boundary: boundary))
        #expect(!rules.offersTomorrowReview(at: LocalTime("09:00"), boundary: boundary))
    }
}
