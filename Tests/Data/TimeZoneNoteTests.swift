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
}
