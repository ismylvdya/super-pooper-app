import CoreGraphics

/// A banner over the navigation bar, on the line of its round buttons: its top as high as theirs, its sides as far from
/// the screen's as theirs, collapsed exactly as tall as they are and as round, so it covers the bar's row of buttons
/// and nothing below it; the buttons stay where they are under it.
struct BannerPlacement: Equatable, Sendable {
    /// From the top of the safe area (where the bar starts).
    let top: CGFloat
    let side: CGFloat
    /// The collapsed banner's height: a bar button's.
    let height: CGFloat
    let radius: CGFloat

    init(bar: CGFloat, button: CGFloat, sideInset: CGFloat) {
        top = (bar - button) / 2
        side = sideInset
        height = button
        radius = button / 2
    }
}
