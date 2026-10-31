import Foundation
import Testing
@testable import SuperPooperApp

/// The app state's events in words: the text, the style, the elements under the text and the page a tap opens.
@MainActor
struct BannerPresenterTests {
    private func banner(_ event: AppEvent) -> BannerCenter.Banner { BannerPresenter.banner(for: event) }

    /// Each kind of change has its own element (an icon and its number); a kind with nothing is left out.
    @Test func aSyncCountsEachKindOnItsOwn() {
        let synced = banner(.synced(added: 2, changed: 0, removed: 1))
        #expect(synced.text == L10n.string("banner.sync.changes"))
        #expect(synced.style == .synced)
        #expect(synced.counts.map(\.icon) == [.syncAdded, .syncRemoved])
        #expect(synced.counts.map(\.value) == [2, 1])
        #expect(synced.counts.map(\.label) == [L10n.format("banner.sync.added", 2), L10n.format("banner.sync.removed", 1)])
    }

    @Test func aSyncWithoutChangesSaysUpToDate() {
        let synced = banner(.synced(added: 0, changed: 0, removed: 0))
        #expect(synced.text == L10n.string("banner.sync.upToDate"))
        #expect(synced.counts.isEmpty)
    }

    /// The conflict banner opens the conflicts page of the Settings tab; other banners open nothing.
    @Test func aConflictOpensTheConflictsPage() {
        let conflict = banner(.conflictsFound(["A", "B"]))
        #expect(conflict.opens == BannerTarget(tab: .settings, routes: [.conflicts]))
        #expect(conflict.items == ["A", "B"])
        #expect(conflict.style == .warning)
        #expect(banner(.promoted(["A"])).opens == nil)
    }

    @Test func clashingFieldsAreListedInWords() {
        let clash = banner(.fieldsClashed(note: "Task", fields: [.due, .status]))
        #expect(clash.text == L10n.format("banner.conflictSameKey", "Task"))
        #expect(clash.items == [TaskFieldText.title(.due), TaskFieldText.title(.status)])
    }

    @Test func aFailureIsAProblemInTheAppsWords() {
        let failure = banner(.failure(.nameTaken("Task")))
        #expect(failure.style == .problem)
        #expect(failure.text == L10n.format("error.rename.taken", "Task"))
        #expect(banner(.failure(.system(domain: "NSCocoaErrorDomain", code: 257))).text
            == L10n.format("error.generic", "NSCocoaErrorDomain", 257))
    }

    @Test func doneThingsAreSuccesses() {
        for event: AppEvent in [.created("A"), .renamed("A"), .archived("A"), .deleted("A"), .restored("A"),
                                .deletedForever("A"), .conflictResolved("A"), .promoted(["A"])] {
            #expect(banner(event).style == .success)
        }
    }
}
