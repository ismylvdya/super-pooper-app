import Foundation

/// Which of the views side by side is drawn above: the lift room of one reaches over its neighbours, and their fades and
/// backings (the all-day strip, a scroll's dissolving edge) must not paint over the shadows that fall there.
enum LiftLayer {
    /// The blocks of a layout: a block's room reaches over the blocks after it (the pool's lifted rows and its "+N more"
    /// over the timeline's top), so earlier blocks are drawn above later ones.
    static func block(at index: Int, of count: Int) -> Double {
        Double(count - index)
    }

    /// What stands beside the blocks and casts a shadow over them (the bar's glass buttons lying sideways): above them all.
    static func beside(blocks count: Int) -> Double {
        Double(count + 1)
    }
}
