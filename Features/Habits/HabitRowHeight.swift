import CoreGraphics

/// One height for every row of the Habits list: the name's line, the gap and the detail line under it, whether the habit
/// has a detail or not.
enum HabitRowHeight {
    static func text(name: CGFloat, gap: CGFloat, detail: CGFloat) -> CGFloat { name + gap + detail }
}
