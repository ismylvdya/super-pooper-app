import SwiftUI

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
        if let onTap, let outline = metrics.outline(of: day.cell) {
            let inset = (metrics.cell - outline) / 2
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
