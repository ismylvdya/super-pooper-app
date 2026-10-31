import Foundation
import Testing
@testable import SuperPooperApp

@Suite("Timeline links")
struct TimelineLinksTests {
    @Test func linkedBlocksAreConnectedThroughTasksAndEvents() {
        let call = makeEvent("Call", from: "19:00", to: "20:00")
        let questions = makeTask("Questions") { $0.due = TaskDue("2026-10-21T15:00"); $0.nextEvent = EventLink(eventIdentifier: call.eventIdentifier, title: "Call", start: call.start) }
        let print = makeTask("Print") { $0.due = TaskDue("2026-10-21T16:00"); $0.previousTasks = ["Questions"] }
        let alone = makeTask("Alone") { $0.due = TaskDue("2026-10-21T17:00") }
        let plan = DayScenario(tasks: [questions, print, alone], events: [call]).build()
        let links = TimelineLinks(slots: plan.timeline, calendar: TestCalendar.calendar, rules: TestConfig.rules.day)
        let id = { (name: String) in plan.slot(name)?.id ?? "" }
        #expect(links.isLinked(id("Print")) && !links.isLinked(id("Alone")))
        #expect(links.connected(to: id("Print")) == [id("Print"), id("Questions"), plan.eventSlot("Call")?.id ?? ""])
    }

    /// A link the Claude skill wrote with any identifier finds its event by title and start, as the day does: the
    /// block gets the link badge and lights up with the event.
    @Test func aLinkFoundByTitleAndStartConnectsTheBlocks() throws {
        let call = makeEvent("Call", from: "19:00", to: "20:00")
        let notes = makeTask("Notes") { $0.due = TaskDue("2026-10-21T21:00"); $0.previousEvent = eventLink(to: call, identifier: "skill") }
        let plan = DayScenario(tasks: [notes], events: [call]).build()
        let links = TimelineLinks(slots: plan.timeline, calendar: TestCalendar.calendar, rules: TestConfig.rules.day)
        let event = try #require(plan.eventSlot("Call")?.id)
        let task = try #require(plan.slot("Notes")?.id)
        #expect(links.isLinked(task))
        #expect(links.connected(to: event) == [event, task])
    }

    /// Task links match names in any letter case, like everywhere else.
    @Test func aTaskLinkInOtherLetterCaseConnectsTheBlocks() throws {
        let water = makeTask("Drink Water") { $0.due = TaskDue("2026-10-21T15:00") }
        let after = makeTask("After") { $0.due = TaskDue("2026-10-21T16:00"); $0.previousTasks = ["drink water"] }
        let plan = DayScenario(tasks: [water, after]).build()
        let links = TimelineLinks(slots: plan.timeline, calendar: TestCalendar.calendar, rules: TestConfig.rules.day)
        #expect(links.isLinked(try #require(plan.slot("After")?.id)))
    }
}
