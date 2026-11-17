import Foundation
import Testing
@testable import SuperPooperApp

/// The review sheet is named Day spreader (D-190); the list it reviews (status `this_week`) is Next actions (D-063).
struct ReviewNameTests {
    @Test func theSheetIsSpreaderAndItsListIsNextActions() {
        #expect(L10n.string("review.title") == "Day spreader")
        #expect(L10n.string("status.thisWeek") == "Next actions")
    }
}
