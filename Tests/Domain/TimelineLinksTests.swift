import Foundation
import Testing
@testable import SuperPooper

@Suite("Timeline links")
struct TimelineLinksTests {
    @Test func linkedBlocksAreConnectedThroughTasksAndEvents() {
        let call = makeEvent("Call", from: "19:00", to: "20:00")
        let questions = makeTask("Questions") { $0.due = TaskDue("2026-10-21T15:00"); $0.nextEvent = EventLink(eventIdentifier: call.eventIdentifier, title: "Call", start: call.start) }
        let print = makeTask("Print") { $0.due = TaskDue("2026-10-21T16:00"); $0.previousTasks = ["Questions"] }
        let alone = makeTask("Alone") { $0.due = TaskDue("2026-10-21T17:00") }
        let plan = DayScenario(tasks: [questions, print, alone], events: [call]).build()
        let links = TimelineLinks(slots: plan.timeline)
        let id = { (name: String) in plan.slot(name)?.id ?? "" }
        #expect(links.isLinked(id("Print")) && !links.isLinked(id("Alone")))
        #expect(links.connected(to: id("Print")) == [id("Print"), id("Questions"), plan.eventSlot("Call")?.id ?? ""])
    }
}
