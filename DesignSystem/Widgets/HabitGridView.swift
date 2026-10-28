import SwiftUI

/// Sizes of a habit day: `dot` (X) is the diameter of the mark, `ring` (Y) the thickness of the rings.
/// Twice adds an outer ring one ring-width away, so a cell is X + 4Y wide; neighbours overlap by Y,
/// which keeps exactly "dot · gap · ring · gap · dot" between two Twice days.
struct HabitDotMetrics: Equatable {
    let dot: CGFloat
    let ringRatio: CGFloat

    var ring: CGFloat { dot * ringRatio }
    var cell: CGFloat { dot + 4 * ring }
    /// Neighbouring cells overlap by one ring width.
    var spacing: CGFloat { -ring }

    /// A cell of the given outer size whose ring and gap are `ring` points (as in a grid of another size).
    static func cell(_ cell: CGFloat, ring: CGFloat) -> HabitDotMetrics {
        let dot = max(cell - 4 * ring, ring)
        return HabitDotMetrics(dot: dot, ringRatio: ring / dot)
    }

    /// The largest dot whose seven cells fit `width`.
    static func fitting(width: CGFloat, ringRatio: CGFloat) -> HabitDotMetrics {
        HabitDotMetrics(dot: max(width / (7 + 22 * ringRatio), 4), ringRatio: ringRatio)
    }
}

/// Weeks of a habit as rows (Monday … Sunday), oldest on top. `onTap`/`menu` make past days markable;
/// the long-press highlight is the mark's circle. The oldest row fades out when `fadesTop` is set (widgets).
struct HabitGridView<Menu: View>: View {
    @Environment(\.tokens) private var tokens
    let grid: HabitGrid
    let color: Color
    let metrics: HabitDotMetrics
    var fadesTop = false
    var onTap: ((LocalDate) -> Void)?
    @ViewBuilder var menu: (LocalDate) -> Menu

    var body: some View {
        VStack(spacing: metrics.spacing) {
            ForEach(Array(grid.weeks.enumerated()), id: \.offset) { index, week in
                HStack(spacing: metrics.spacing) {
                    ForEach(week, id: \.date) { day in
                        cell(day)
                    }
                }
                .opacity(fadesTop && index == 0 && grid.weeks.count > 1 ? tokens.opacity(.gridFadedWeek) : 1)
            }
        }
    }

    @ViewBuilder private func cell(_ day: HabitGrid.Day) -> some View {
        let view = HabitDayCell(cell: day.cell, color: color, metrics: metrics)
        if let onTap, day.cell != .future {
            let inset = day.cell == .twice ? 0 : 2 * metrics.ring
            view
                .contentShape(Circle().inset(by: inset))
                .contentShape(.contextMenuPreview, Circle().inset(by: inset))
                .onTapGesture { onTap(day.date) }
                .contextMenu { menu(day.date) }
                .accessibilityLabel(Text(verbatim: day.date.isoString))
                .accessibilityAddTraits(.isButton)
        } else {
            view
        }
    }
}

extension HabitGridView where Menu == EmptyView {
    init(grid: HabitGrid, color: Color, metrics: HabitDotMetrics, fadesTop: Bool = false) {
        self.init(grid: grid, color: color, metrics: metrics, fadesTop: fadesTop, onTap: nil) { _ in EmptyView() }
    }
}

/// Monday … Sunday initials above a habit grid, one per cell.
struct WeekdayHeader: View {
    @Environment(\.tokens) private var tokens
    @Environment(\.calendar) private var calendar
    let metrics: HabitDotMetrics

    var body: some View {
        HStack(spacing: metrics.spacing) {
            ForEach(Weekday.allCases, id: \.self) { day in
                Text(verbatim: day.name(.initial, in: calendar))
                    .font(tokens.font(.caption))
                    .foregroundStyle(tokens.color(.secondaryText))
                    .frame(width: metrics.cell)
            }
        }
    }
}

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
                Circle().fill(color).frame(width: dot * tokens.size(.habitPartialDot), height: dot * tokens.size(.habitPartialDot))
            case .open, .missed, .notScheduled:
                Circle().strokeBorder(color, lineWidth: metrics.ring).frame(width: dot, height: dot)
            }
        }
        .frame(width: metrics.cell, height: metrics.cell)
    }
}

/// The habit marks as template images from the asset catalog (they take the menu's text color). The same
/// images are the icons of the habit notification buttons.
enum HabitMarkIcon {
    static func icon(for mark: HabitMark?) -> Icon {
        switch mark {
        case nil: .habitMarkOpen
        case .done: .habitMarkDone
        case .partial: .habitMarkPartial
        case .twice: .habitMarkTwice
        }
    }

    /// The habit mark an action stands for, if it is one.
    static func icon(for action: ActionID) -> Icon? {
        switch action {
        case .done: .habitMarkDone
        case .partial: .habitMarkPartial
        case .twice: .habitMarkTwice
        case .unmark: .habitMarkOpen
        default: nil
        }
    }
}

extension DesignTokens {
    /// A habit's own color (`habit_color`), or the habit color of the palette.
    func habitColor(_ task: TaskNote) -> Color {
        task.habit.color.flatMap { UIColor(hex: $0) }.map(Color.init(uiColor:)) ?? color(.habit)
    }

    /// A habit's name: in its own color when it has one; the settings' habit color is for marks and chips only.
    func habitNameColor(_ task: TaskNote) -> Color {
        task.habit.color.flatMap { UIColor(hex: $0) }.map(Color.init(uiColor:)) ?? color(.primaryText)
    }
}
