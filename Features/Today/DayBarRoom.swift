import CoreGraphics

/// The room the navigation bar leaves for the day's name and its arrows between its button groups. The bar lays its
/// middle item out at its own ideal width and only centres it, so an item wider than the room reaches under the buttons
/// beside it, which then take the taps meant for the arrows. Measured from where the buttons stand, a gap of the bar's
/// button spacing kept on each side. The room is as wide on both sides of `center` (the screen's middle), so the name
/// stays centred even when one group is wider.
enum DayBarRoom {
    /// nil until both groups have been measured.
    static func width(leading: [CGRect], trailing: [CGRect], gap: CGFloat, center: CGFloat) -> CGFloat? {
        guard let end = leading.map(\.maxX).max(), let start = trailing.map(\.minX).min() else { return nil }
        return max(min(center - end, start - center) * 2 - gap * 2, 0)
    }
}
