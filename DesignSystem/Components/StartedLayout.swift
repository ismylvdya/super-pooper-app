import CoreGraphics

/// Where a started task's mark stands on its pool plate and how far its name moves right for it
/// (`AppSettings.Pool.StartedLook`).
struct StartedLayout: Equatable {
    var look: AppSettings.StartedLook
    /// How far the fill reaches, as a share of the plate's width.
    var fillLength: Double
    var titleAfterFill: Bool
    /// How big the circle is, from the smallest it can be (0) to the largest (1) (`DesignTokens.startedCircleSizes`).
    var circleSize: Double = 1
    /// The circle's fade: where across it its middle stands, and how wide it is (0: a sharp edge), as shares of the circle.
    var fadeMiddle: Double = 0.5
    var fadeWidth: Double = 0.5
    /// Points from the circle to the name; below zero the name moves back over the circle, at most to where it stands
    /// on a task not started.
    var titleGap: Double = 0

    /// The circle: concentric with the plate's top-left corner, so the gap to the plate's edge is the same all along the
    /// arc; as big as `circleSize` says between `sizes`, never past the plate. A plate is never rounder than half its height.
    func circle(plateHeight: CGFloat, cornerRadius: CGFloat, sizes: ClosedRange<CGFloat>) -> CGRect? {
        guard look == .circle else { return nil }
        let corner = min(cornerRadius, plateHeight / 2)
        let share = CGFloat(min(max(circleSize, 0), 1))
        let radius = min(sizes.lowerBound + (sizes.upperBound - sizes.lowerBound) * share, corner * 2) / 2
        return CGRect(x: corner - radius, y: corner - radius, width: radius * 2, height: radius * 2)
    }

    /// How far right of its usual place the name starts: `titleGap` past the circle, never left of its usual place, or
    /// past the end of the fill when the name goes after it.
    func titleShift(plateSize: CGSize, cornerRadius: CGFloat, sizes: ClosedRange<CGFloat>, inset: CGFloat) -> CGFloat {
        switch look {
        case .circle:
            guard let circle = circle(plateHeight: plateSize.height, cornerRadius: cornerRadius, sizes: sizes) else { return 0 }
            return max(circle.maxX + CGFloat(titleGap) - inset, 0)
        case .fill:
            guard titleAfterFill else { return 0 }
            return max(plateSize.width * CGFloat(min(max(fillLength, 0), 1)) - inset, 0)
        }
    }
}
