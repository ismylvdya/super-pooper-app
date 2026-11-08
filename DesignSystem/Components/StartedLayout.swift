import CoreGraphics

/// Where a started task's mark stands on its pool plate and how far its name moves right for it
/// (`AppSettings.Pool.StartedLook`).
struct StartedLayout: Equatable {
    var look: AppSettings.StartedLook
    /// How far the fill reaches, as a share of the plate's width.
    var fillLength: Double
    var titleAfterFill: Bool

    /// The circle: concentric with the plate's top-left corner, `inset` inside it (the row's leading inset), so the
    /// gap to the plate's edge is the same all along the arc. A plate is never rounder than half its height.
    func circle(plateHeight: CGFloat, cornerRadius: CGFloat, inset: CGFloat) -> CGRect? {
        guard look == .circle else { return nil }
        let corner = min(cornerRadius, plateHeight / 2)
        let radius = max(corner - inset, 0)
        return CGRect(x: corner - radius, y: corner - radius, width: radius * 2, height: radius * 2)
    }

    /// How far right of its usual place the name starts: past the circle and `gap`, or past the end of the fill when
    /// the name goes after it.
    func titleShift(plateSize: CGSize, cornerRadius: CGFloat, inset: CGFloat, gap: CGFloat) -> CGFloat {
        switch look {
        case .circle:
            guard let circle = circle(plateHeight: plateSize.height, cornerRadius: cornerRadius, inset: inset) else { return 0 }
            return circle.maxX + gap - inset
        case .fill:
            guard titleAfterFill else { return 0 }
            return max(plateSize.width * CGFloat(min(max(fillLength, 0), 1)) - inset, 0)
        }
    }
}
