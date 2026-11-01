import Foundation
import Testing
@testable import SuperPooperApp

/// The Today pages: each leaves its neighbour's own peek in sight — the timeline's edge beside the pool, only a sliver
/// of the pool (half of its last chip) beside the timeline.
struct PageStripTests {
    private let strip = PageStrip(count: 2, width: 343, spacing: 16, peeks: [10, 52])

    @Test func eachPageLeavesItsNeighboursPeek() {
        #expect(strip.width(of: 0) == CGFloat(343 - 52 - 16))
        #expect(strip.width(of: 1) == CGFloat(343 - 10 - 16))
        #expect(strip.offset(showing: 0) == 0)
        // The pool's right edge ends 10 points into the stack, the timeline fills the rest to the edge.
        let shown = strip.offset(showing: 1)
        #expect(shown + strip.width(of: 0) == 10)
        #expect(shown + strip.width(of: 0) + 16 + strip.width(of: 1) == 343)
    }
}
