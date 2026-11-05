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

    /// Beside the pool nothing of the last list is in sight even when the pages stand closer than the screen's margin;
    /// the list itself still keeps the pool's peek.
    @Test func thePoolHidesTheListBesideIt() {
        let strip = PageStrip(count: 3, width: 343, spacing: 8, peeks: [0, 0, 52], edgeInset: 16, home: 1, listCount: 1, listPeek: 14)
        #expect(strip.origin(of: 0) + strip.width(of: 0) + strip.offset(showing: 1) == -16)
        #expect(strip.offset(showing: 0) + strip.origin(of: 1) == CGFloat(343 - 14))
    }

    /// A strip of four (two backlog pages without a peek, the pool, the timeline): every page has its own offset, the
    /// hidden pages stand beyond the screen's margin, and places count from the pool, so pages added before it move
    /// nothing in sight.
    @Test func everyPageOfAStripHasItsOwnPeek() {
        let strip = PageStrip(count: 4, width: 343, spacing: 16, peeks: [0, 0, 10, 52], edgeInset: 16, home: 2)
        #expect(strip.width(of: 0) == 343)
        #expect(strip.width(of: 1) == CGFloat(343 - 10 - 16), "Soon keeps the pool's peek in sight")
        #expect(strip.width(of: 2) == CGFloat(343 - 52 - 16), "the pool keeps its width beside a hidden page")
        #expect(strip.origin(of: 2) == 0)
        #expect(strip.offset(showing: 2) == 0)
        #expect(strip.offset(showing: 1) == CGFloat(343 - 10 - 16 + 16))
        #expect(strip.offset(showing: 0) == strip.offset(showing: 1) + 343 + 16)
        // Showing the pool, Soon ends a margin's width before the stack: beyond the screen's edge.
        #expect(strip.origin(of: 1) + strip.width(of: 1) + strip.offset(showing: 2) == -16)
        #expect(strip.offset(showing: -1) == strip.offset(showing: 0) && strip.offset(showing: 9) == strip.offset(showing: 3))
        let shorter = PageStrip(count: 3, width: 343, spacing: 16, peeks: [0, 10, 52], edgeInset: 16, home: 1)
        #expect(shorter.origin(of: 1) == strip.origin(of: 2) && shorter.origin(of: 0) == strip.origin(of: 1))
    }
}
