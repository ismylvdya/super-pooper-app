import SwiftUI

/// One day of a habit, the same everywhere (list, grid, widget, menus).
/// not done = ring (faded), Partially = the Start glyph, Done = filled circle, Twice = filled circle with an
/// outer ring. Quantities show the recorded number. Future days are empty. On a plate, a day is backed by the plate's color in the shape of its outer edge, so
/// lifted by a long press it is opaque between its rings and dot, and the days under it never show through.
struct HabitDayCell: View {
    @Environment(\.tokens) private var tokens
    @Environment(\.icons) private var icons
    @Environment(\.plateSurface) private var surface
    let cell: HabitCell
    let color: Color
    let metrics: HabitDotMetrics

    var body: some View {
        let dot = metrics.dot
        ZStack {
            if let surface, let outline = metrics.outline(of: cell) {
                Circle().fill(surface).frame(width: outline, height: outline)
            }
            switch cell {
            case .future:
                Color.clear
            case .done:
                Circle().fill(color).frame(width: dot, height: dot)
            case .quantity(let amount):
                Circle().fill(color).frame(width: dot, height: dot)
                    .overlay {
                        Text(amount, format: .number.grouping(.never))
                            .font(tokens.font(.caption))
                            .monospacedDigit()
                            .lineLimit(1)
                            .minimumScaleFactor(0.5)
                            .foregroundStyle(surface ?? tokens.color(.plateBackground))
                    }
            case .twice:
                Circle().fill(color).frame(width: dot, height: dot)
                Circle().strokeBorder(color, lineWidth: metrics.ring).frame(width: metrics.cell, height: metrics.cell)
            case .partial:
                Image(icon: HabitMarkIcon.icon(for: .partial), icons: icons)
                    .resizable()
                    .scaledToFit()
                    .foregroundStyle(color)
                    .frame(width: dot, height: dot)
            case .open, .missed, .notScheduled:
                Circle().strokeBorder(openRing, lineWidth: metrics.ring).frame(width: dot, height: dot)
            }
        }
        .frame(width: metrics.cell, height: metrics.cell)
    }

    /// The ring of a day not done, or done partly, stands back (`opacity.habitOpenRing`).
    private var openRing: Color { color.opacity(tokens.opacity(.habitOpenRing)) }
}
