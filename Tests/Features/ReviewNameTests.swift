import Foundation
import Testing
@testable import SuperPooperApp

/// The review sheet is named Spreader (D-187); the list it reviews (status `this_week`) is Next actions (D-063).
struct ReviewNameTests {
    @Test func theSheetIsSpreaderAndItsListIsNextActions() {
        #expect(L10n.string("review.title") == "Spreader")
        #expect(L10n.string("status.thisWeek") == "Next actions")
    }
}
