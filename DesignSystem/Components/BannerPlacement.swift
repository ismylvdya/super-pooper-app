import CoreGraphics

/// A banner over the navigation bar, concentric with its round buttons: its top as high as theirs, its sides as far from
/// the screen's as theirs, its corners as round as they are, so each corner lies on the circle of the button under it.
struct BannerPlacement: Equatable, Sendable {
    /// From the top of the safe area (where the bar starts).
    let top: CGFloat
    let side: CGFloat
    let radius: CGFloat

    init(bar: CGFloat, button: CGFloat, sideInset: CGFloat) {
        top = (bar - button) / 2
        side = sideInset
        radius = button / 2
    }
}
