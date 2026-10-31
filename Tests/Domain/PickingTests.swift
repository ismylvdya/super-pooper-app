import Foundation
import Testing
@testable import SuperPooperApp

/// What the event and task pickers of the task page offer.
struct PickingTests {
    private let context = TestCalendar.context(TestCalendar.wednesday, "13:25")

    /// From now (an event still running counts) until the end of the last day of the window, by day, in time order.
    @Test func theEventPickerShowsTheNextDaysByDay() {
        let events = [
            makeEvent("Over", from: "09:00", to: "10:00"),
            makeEvent("Running", from: "13:00", to: "14:00"),
            makeEvent("Thursday", day: "2026-10-22", from: "09:00", to: "10:00"),
            makeEvent("Friday", day: "2026-10-23", from: "09:00", to: "10:00"),
        ]
        let days = EventPicking.days(events, matching: "", daysAhead: 2, context: context)
        #expect(days.map(\.day) == [LocalDate("2026-10-21"), LocalDate("2026-10-22")])
        #expect(days.map { $0.events.map(\.title) } == [["Running"], ["Thursday"]])
    }

    @Test func theEventPickerFindsTitlesInAnyCase() {
        let events = [makeEvent("Call with dad", from: "19:00", to: "20:00"), makeEvent("Gym", from: "18:00", to: "19:00")]
        let days = EventPicking.days(events, matching: "DAD", daysAhead: 7, context: context)
        #expect(days.flatMap(\.events).map(\.title) == ["Call with dad"])
    }

    /// The note itself, its links already and archived notes are not offered; the rest by name.
    @Test func linkCandidatesLeaveOutTheNoteItsLinksAndTheArchive() {
        let tasks = [makeTask("Report"), makeTask("Call bank"), makeTask("Archived", status: .archived), makeTask("Buy milk"),
                     makeHabit("Water")]
        #expect(LinkCandidates.tasks(tasks, excluding: ["Report", "Call bank"], matching: "").map(\.name) == ["Buy milk", "Water"])
        #expect(LinkCandidates.tasks(tasks, excluding: [], matching: "bank").map(\.name) == ["Call bank"])
    }

    /// A link written in another letter case (`[[call bank]]` to "Call bank") is the same note (D-052): it is not offered
    /// again, which would link the note twice.
    @Test func aLinkInAnotherCaseIsNotOfferedAgain() {
        let tasks = [makeTask("Report"), makeTask("Call bank"), makeTask("Buy milk")]
        #expect(LinkCandidates.tasks(tasks, excluding: ["report", "call BANK"], matching: "").map(\.name) == ["Buy milk"])
    }
}
