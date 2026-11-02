import SwiftUI

/// Sizes of a habit day: `dot` (X) is the diameter of the mark, `ring` (Y) the thickness of the rings.
/// Twice adds an outer ring one ring-width away, so a cell is X + 4Y wide; neighbours overlap by Y,
/// which keeps exactly "dot · gap · ring · gap · dot" between two Twice days.
struct HabitDotMetrics: Equatable {
    let dot: CGFloat
    let ringRatio: CGFloat

    var ring: CGFloat { dot * ringRatio }
    var cell: CGFloat { dot + 4 * ring }
    /// Neighbouring cells overlap by one ring width.
    var spacing: CGFloat { -ring }

    /// How much taller a grid grows with `weeks` more rows.
    func height(ofWeeks weeks: Int) -> CGFloat { CGFloat(weeks) * (cell + spacing) }

    /// The diameter of a day's outer edge: the outer ring of Twice, the circle of every other mark; a future day has none.
    func outline(of cell: HabitCell) -> CGFloat? {
        switch cell {
        case .future: nil
        case .twice: self.cell
        case .done, .partial, .open, .missed, .notScheduled: dot
        }
    }

    /// A cell of the given outer size whose ring and gap are `ring` points (as in a grid of another size).
    static func cell(_ cell: CGFloat, ring: CGFloat) -> HabitDotMetrics {
        let dot = max(cell - 4 * ring, ring)
        return HabitDotMetrics(dot: dot, ringRatio: ring / dot)
    }

    /// The largest dot whose seven cells fit `width`, not smaller than `minimumDot`.
    static func fitting(width: CGFloat, ringRatio: CGFloat, minimumDot: CGFloat) -> HabitDotMetrics {
        HabitDotMetrics(dot: max(width / (7 + 22 * ringRatio), minimumDot), ringRatio: ringRatio)
    }
}

extension DesignTokens {
    /// The habit dots of a grid as wide as `width`: the ring of the tokens, the dot as large as fits.
    func habitDots(fitting width: CGFloat) -> HabitDotMetrics {
        HabitDotMetrics.fitting(width: width, ringRatio: ratio(.habitRing), minimumDot: size(.habitDotMinimum))
    }
}
