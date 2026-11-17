import Foundation
import Testing
@testable import SuperPooperApp

/// The review sheet is named Raskidыvatel (D-187); the list it reviews (status `this_week`) is Next actions (D-063).
struct ReviewNameTests {
    @Test func theSheetIsRaskidyvatelAndItsListIsNextActions() {
        #expect(L10n.string("review.title") == "Raskidыvatel")
        #expect(L10n.string("status.thisWeek") == "Next actions")
    }
}
