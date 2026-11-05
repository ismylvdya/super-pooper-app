import Foundation
import Testing
@testable import SuperPooperApp

/// The review sheet is named Morning review; the list it reviews (status `this_week`) is still Soon (D-063).
struct ReviewNameTests {
    @Test func theSheetIsMorningReviewAndItsListStaysSoon() {
        #expect(L10n.string("review.title") == "Morning review")
        #expect(L10n.string("status.thisWeek") == "Next actions")
    }
}
