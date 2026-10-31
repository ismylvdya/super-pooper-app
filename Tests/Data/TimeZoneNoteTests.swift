import Foundation
import Testing
@testable import SuperPooperApp

/// Notes written while the phone changes its time zone. Times of day are wall-clock and written without a zone, as
/// TaskNotes writes them; only the moments TaskNotes stamps with an offset (`date_modified`) take the phone's zone,
/// the one it has at the time of writing. The vault is rendered for Wednesday 2026-10-21; "now" is 13:25 in Belgrade.
@Suite("Time zones in notes")
struct TimeZoneNoteTests {
    @Test func aWriteAfterAZoneChangeStampsTheNewZone() async throws {
        let calendar = TravellingCalendar("Europe/Belgrade")
        let note = try await SandboxNote("Позвонить в банк", calendar: calendar)
        try await note.apply([.highPriority(true)])
        #expect(try note.text().contains("date_modified: 2026-10-21T13:25:00.000+02:00\n"))

        calendar.fly(to: "Asia/Jakarta")
        try await note.apply([.due(TaskDue("2026-11-06"))])
        let text = try note.text()
        #expect(text.contains("date_modified: 2026-10-21T18:25:00.000+07:00\n"))
        #expect(text.contains("due: 2026-11-06\n"))
    }

    /// An event link carries the event's start as a moment with an offset: the phone's zone at the time of writing.
    @Test func anEventLinkWrittenAfterAZoneChangeCarriesTheNewOffset() async throws {
        let calendar = TravellingCalendar("Europe/Belgrade")
        let note = try await SandboxNote("Позвонить в банк", calendar: calendar)
        let event = makeEvent("Call with dad", from: "19:00", to: "20:00", id: "EK1")
        calendar.fly(to: "Asia/Jakarta")
        try await note.apply([.previousEvent(eventLink(to: event))])
        #expect(try note.text().contains("previous_event: \"EK1|Call with dad|2026-10-22T00:00:00+07:00\"\n"))
        #expect(note.task.previousEvent?.start == event.start)
    }

    /// A `due` written as a moment by someone else is read on the clock of the zone the phone has at the scan.
    @Test func aMomentInANoteIsReadInTheZoneOfTheScan() async throws {
        let calendar = TravellingCalendar("Europe/Belgrade")
        let note = try await SandboxNote("Позвонить в банк", calendar: calendar)
        let text = try note.text()
        let line = try #require(text.split(separator: "\n").first { $0.hasPrefix("status:") })
        try note.sandbox.write(try text.replacingOnce(String(line), with: "\(line)\ndue: 2026-11-06T08:00Z"), to: "Позвонить в банк")
        #expect(try await note.reload().due == TaskDue("2026-11-06T09:00"))

        calendar.fly(to: "Asia/Jakarta")
        #expect(try await note.reload().due == TaskDue("2026-11-06T15:00"))
    }
}
