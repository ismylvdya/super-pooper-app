import CoreGraphics

/// A banner in the navigation bar, between its round buttons (back, search), so they can always be pressed: exactly as tall
/// as they are and as round, as far from each of them as they are from the screen's side. Sideways, where no bar stands at the
/// top, the same but as far from the top as from the sides.
struct BannerPlacement: Equatable, Sendable {
    /// From the top of the safe area, where the bar starts.
    let top: CGFloat
    /// From the top of the safe area with the phone lying sideways.
    let sidewaysTop: CGFloat
    let side: CGFloat
    /// The collapsed banner's height: a bar button's.
    let height: CGFloat
    let radius: CGFloat

    init(bar: CGFloat, button: CGFloat, sideInset: CGFloat) {
        top = (bar - button) / 2
        sidewaysTop = sideInset
        side = sideInset + button + sideInset
        height = button
        radius = button / 2
    }
}
