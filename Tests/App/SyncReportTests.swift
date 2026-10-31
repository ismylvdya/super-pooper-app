import Foundation
import Testing
@testable import SuperPooperApp

/// What the banner after pull to refresh counts.
struct SyncReportTests {
    @Test func newChangedAndRemovedNotesAreCounted() {
        let kept = makeTask("Kept")
        let edited = makeTask("Edited")
        var editedLater = edited
        editedLater.isHighPriority = true
        let report = SyncReport(old: [kept, edited, makeTask("Gone")], new: [kept, editedLater, makeTask("New B"), makeTask("New A")])
        #expect(report.added == ["New A", "New B"])
        #expect(report.changed == ["Edited"])
        #expect(report.removed == ["Gone"])
        #expect(report.summary == L10n.format("banner.sync.changes", 2, 1, 1))
    }

    /// A note only touched (its `date_modified` moved) is not a change.
    @Test func aNewTimestampAloneIsNotAChange() {
        let note = makeTask("Note")
        var touched = note
        touched.dateModified = TestCalendar.date(TestCalendar.wednesday, "12:00")
        let report = SyncReport(old: [note], new: [touched])
        #expect(report.changed.isEmpty)
        #expect(report.summary == L10n.string("banner.sync.upToDate"))
    }
}
