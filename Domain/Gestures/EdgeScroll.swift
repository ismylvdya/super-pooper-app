import Foundation

/// Which way a list scrolls by itself under a dragged "+": up while it stays in the band at the top of the list's visible
/// part, down in the band at its bottom, as far as there is to scroll.
enum EdgeScroll {
    enum Direction: Int, Sendable { case up = -1, none = 0, down = 1 }

    /// `y`: the finger; `top` and `bottom`: the list's visible part, on the same axis.
    static func direction(y: Double, top: Double, bottom: Double, band: Double) -> Direction {
        guard y >= top, y <= bottom else { return .none }
        if y < top + band { return .up }
        if y > bottom - band { return .down }
        return .none
    }

    /// The next offset: `step` further that way, never past either end.
    static func offset(_ offset: Double, _ direction: Direction, step: Double, maximum: Double) -> Double {
        min(max(offset + Double(direction.rawValue) * step, 0), max(maximum, 0))
    }
}
