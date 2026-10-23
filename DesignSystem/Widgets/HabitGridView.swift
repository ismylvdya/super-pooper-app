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

/// One day of a habit: Done is filled with the habit color, Partially is pale with a half mark,
/// Twice has an inner square, missed days are tinted, an unmarked today is outlined.
struct HabitDayCell: View {
    @Environment(\.tokens) private var tokens
    @Environment(\.icons) private var icons
    let cell: HabitCell
    let color: Color
    var isToday = false

    var body: some View {
        GeometryReader { geometry in
            let side = min(geometry.size.width, geometry.size.height)
            let shape = RoundedRectangle(cornerRadius: side * tokens.size(.habitCellRadiusRatio), style: .continuous)
            ZStack {
                switch cell {
                case .done:
                    shape.fill(color)
                case .partial:
                    shape.fill(color.opacity(tokens.opacity(.partialFill)))
                    Image(systemName: icons[.markPartial])
                        .resizable().scaledToFit()
                        .foregroundStyle(color)
                        .frame(width: side * 0.5, height: side * 0.5)
                case .twice:
                    shape.fill(color)
                    RoundedRectangle(cornerRadius: side * tokens.size(.habitCellRadiusRatio) / 2, style: .continuous)
                        .fill(.black.opacity(tokens.opacity(.twiceInner)))
                        .frame(width: side * 0.45, height: side * 0.45)
                case .open:
                    shape.fill(color.opacity(tokens.opacity(.habitEmpty)))
                case .missed:
                    shape.fill(tokens.color(.missed).opacity(tokens.opacity(.missedFill)))
                case .notScheduled:
                    shape.strokeBorder(color.opacity(tokens.opacity(.habitEmpty)), lineWidth: 1)
                case .future:
                    Color.clear
                }
                if isToday, cell == .open || cell == .missed {
                    shape.strokeBorder(color, lineWidth: max(side * 0.08, 1.5))
                }
            }
            .frame(width: side, height: side)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }
}

extension DesignTokens {
    /// A habit's own color (`habit_color`), or the habit color of the palette.
    func habitColor(_ task: TaskNote) -> Color {
        task.habit.color.flatMap { UIColor(hex: $0) }.map(Color.init(uiColor:)) ?? color(.habit)
    }
}
