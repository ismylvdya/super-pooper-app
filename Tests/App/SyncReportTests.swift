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
        #expect(report.summary == L10n.string("banner.sync.changes"))
        #expect(report.counts.map(\.icon) == [.syncAdded, .syncChanged, .syncRemoved])
        #expect(report.counts.map(\.value) == [2, 1, 1])
    }

    /// A note only touched (its `date_modified` moved) is not a change.
    @Test func aNewTimestampAloneIsNotAChange() {
        let note = makeTask("Note")
        var touched = note
        touched.dateModified = TestCalendar.date(TestCalendar.wednesday, "12:00")
        let report = SyncReport(old: [note], new: [touched])
        #expect(report.changed.isEmpty)
        #expect(report.summary == L10n.string("banner.sync.upToDate"))
        #expect(report.counts.isEmpty)
    }

    /// Each kind has its own element in the banner (an icon and its number); a kind with nothing is left out.
    @Test func aKindWithNothingIsLeftOut() {
        let report = SyncReport(old: [makeTask("Gone")], new: [makeTask("New")])
        #expect(report.counts.map(\.icon) == [.syncAdded, .syncRemoved])
        #expect(report.counts.map(\.label) == [L10n.format("banner.sync.added", 1), L10n.format("banner.sync.removed", 1)])
    }
}
