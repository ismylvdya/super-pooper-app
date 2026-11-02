import CoreGraphics

/// The room the navigation bar leaves for the day's name and its arrows between its button groups. The bar lays its
/// middle item out at its own ideal width and only centres it, so an item wider than the room reaches under the buttons
/// beside it, which then take the taps meant for the arrows. Measured from where the buttons stand, a gap of the bar's
/// button spacing kept on each side.
enum DayBarRoom {
    /// nil until both groups have been measured.
    static func width(leading: [CGRect], trailing: [CGRect], gap: CGFloat) -> CGFloat? {
        guard let end = leading.map(\.maxX).max(), let start = trailing.map(\.minX).min() else { return nil }
        return max(start - end - gap * 2, 0)
    }
}
