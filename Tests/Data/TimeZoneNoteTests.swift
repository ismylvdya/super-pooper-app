import Foundation
import Testing
@testable import SuperPooperApp

/// Notes written while the phone changes its time zone. Times of day are wall-clock and written without a zone, as
/// TaskNotes writes them; only the moments TaskNotes stamps with an offset (`date_modified`) take the phone's zone,
/// the one it has at the time of writing. The vault is rendered for Wednesday 2026-10-21; "now" is 13:25 in Belgrade.
@Suite("Time zones in notes")
struct TimeZoneNoteTests {
}
