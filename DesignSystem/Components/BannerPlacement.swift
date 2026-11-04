import CoreGraphics

/// A banner just under the navigation bar's round buttons, so they can always be pressed: as far below them as they are
/// below the status bar, its sides as far from the screen's as theirs, collapsed exactly as tall as they are and as round.
struct BannerPlacement: Equatable, Sendable {
    /// From the top of the safe area (where the bar starts).
    let top: CGFloat
    let side: CGFloat
    /// The collapsed banner's height: a bar button's.
    let height: CGFloat
    let radius: CGFloat

    init(bar: CGFloat, button: CGFloat, sideInset: CGFloat, gapBelowButtons: CGFloat) {
        top = (bar + button) / 2 + gapBelowButtons
        side = sideInset
        height = button
        radius = button / 2
    }
}
