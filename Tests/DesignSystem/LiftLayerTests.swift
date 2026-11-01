import Testing
@testable import SuperPooperApp

/// Shadows in Today are not cut by the views beside them (.23474): a block's lift room reaches over the blocks after it
/// (the pool's lifted rows and its "+N more" over the timeline's all-day strip and fading top), and the bar's glass
/// buttons lying sideways cast theirs over every block.
struct LiftLayerTests {
    @Test func earlierBlocksAreDrawnAboveLaterOnes() {
        let count = 3
        let layers = (0..<count).map { LiftLayer.block(at: $0, of: count) }
        #expect(layers == layers.sorted(by: >))
        #expect(Set(layers).count == count)
        #expect(layers.allSatisfy { $0 > 0 }, "above what has no layer of its own")
    }

    @Test func theButtonsBesideTheBlocksAreAboveThemAll() {
        for count in 1...3 {
            let top = (0..<count).map { LiftLayer.block(at: $0, of: count) }.max() ?? 0
            #expect(LiftLayer.beside(blocks: count) > top)
        }
    }
}
