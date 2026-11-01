import SwiftUI

/// One day of a habit, the same everywhere (list, grid, widget, menus). Four looks only:
/// not done = ring, Partially = ring with a dot, Done = filled circle, Twice = filled circle with an
/// outer ring. Future days are empty.
struct HabitDayCell: View {
    @Environment(\.tokens) private var tokens
    let cell: HabitCell
    let color: Color
    let metrics: HabitDotMetrics

    var body: some View {
        let dot = metrics.dot
        ZStack {
            switch cell {
            case .future:
                Color.clear
            case .done:
                Circle().fill(color).frame(width: dot, height: dot)
            case .twice:
                Circle().fill(color).frame(width: dot, height: dot)
                Circle().strokeBorder(color, lineWidth: metrics.ring).frame(width: metrics.cell, height: metrics.cell)
            case .partial:
                Circle().strokeBorder(color, lineWidth: metrics.ring).frame(width: dot, height: dot)
                Circle().fill(color).frame(width: dot * tokens.ratio(.habitPartialDot), height: dot * tokens.ratio(.habitPartialDot))
            case .open, .missed, .notScheduled:
                Circle().strokeBorder(color, lineWidth: metrics.ring).frame(width: dot, height: dot)
            }
        }
        .frame(width: metrics.cell, height: metrics.cell)
    }
}
