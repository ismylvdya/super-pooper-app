import SwiftUI

/// Weeks of a habit as rows (Monday … Sunday), oldest on top. Cells fill the width; the oldest
/// row fades out when `fadesTop` is set (widgets). `onTap`/`menu` make past days markable.
struct HabitGridView<Menu: View>: View {
    @Environment(\.tokens) private var tokens
    let grid: HabitGrid
    let color: Color
    var today: LocalDate?
    var fadesTop = false
    var onTap: ((LocalDate) -> Void)?
    @ViewBuilder var menu: (LocalDate) -> Menu

    var body: some View {
        let gap = tokens.space(.habitCellGap)
        VStack(spacing: gap) {
            ForEach(Array(grid.weeks.enumerated()), id: \.offset) { index, week in
                HStack(spacing: gap) {
                    ForEach(week, id: \.date) { day in
                        cell(day)
                    }
                }
                .opacity(fadesTop && index == 0 && grid.weeks.count > 1 ? tokens.opacity(.gridFadedWeek) : 1)
            }
        }
    }

    @ViewBuilder private func cell(_ day: HabitGrid.Day) -> some View {
        let view = HabitDayCell(cell: day.cell, color: color, isToday: day.date == today)
            .aspectRatio(1, contentMode: .fit)
        if let onTap, day.cell != .future {
            view
                .contentShape(Rectangle())
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
    init(grid: HabitGrid, color: Color, today: LocalDate? = nil, fadesTop: Bool = false) {
        self.init(grid: grid, color: color, today: today, fadesTop: fadesTop, onTap: nil) { _ in EmptyView() }
    }
}

/// One day of a habit as a round checkbox, the same in the list, the grid and the widget (SF Symbols
/// from icons.json): open = ring, Done = filled, Partially = ring with a dot, Twice = filled with an
/// outer ring; missed days are rings in the "missed" color, unscheduled days dotted rings.
struct HabitDayCell: View {
    @Environment(\.tokens) private var tokens
    @Environment(\.icons) private var icons
    let cell: HabitCell
    let color: Color
    var isToday = false

    var body: some View {
        Group {
            if let icon {
                Image(systemName: icons[icon])
                    .resizable()
                    .scaledToFit()
                    .fontWeight(isToday ? .semibold : .regular)
                    .foregroundStyle(tint)
            } else {
                Color.clear
            }
        }
        .aspectRatio(1, contentMode: .fit)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var icon: Icon? {
        switch cell {
        case .open, .missed: .habitOpen
        case .done: .habitDone
        case .partial: .habitPartial
        case .twice: .habitTwice
        case .notScheduled: .habitNotScheduled
        case .future: nil
        }
    }

    private var tint: Color {
        switch cell {
        case .missed: tokens.color(.missed)
        case .notScheduled: color.opacity(tokens.opacity(.habitEmpty))
        default: color
        }
    }
}

extension DesignTokens {
    /// A habit's own color (`habit_color`), or the habit color of the palette.
    func habitColor(_ task: TaskNote) -> Color {
        task.habit.color.flatMap { UIColor(hex: $0) }.map(Color.init(uiColor:)) ?? color(.habit)
    }
}
