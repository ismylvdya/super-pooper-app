import AppIntents
import SwiftUI
import WidgetKit

/// The habit widget: the name in the habit's color, today's entry in the corner and the last weeks at the bottom.
/// Completion habits can be marked directly on the widget. All of it is in
/// the habit's color, so all of it takes the accent of a Home Screen tinted in one color. The system puts its margins
/// around it.
struct HabitWidgetView: View {
    @Environment(\.tokens) private var tokens
    let habit: TaskItem
    let grid: HabitGrid
    let today: LocalDate
    var options = HabitWidgetOptions()

    var body: some View {
        GeometryReader { geometry in
            content(metrics: tokens.habitDots(fitting: geometry.size.width))
        }
    }

    private func content(metrics: HabitDotMetrics) -> some View {
        let color = tokens.habitColor(habit)
        return VStack(alignment: .leading, spacing: tokens.space(.widgetGridGap)) {
            HStack(alignment: .top, spacing: tokens.space(.widgetGap)) {
                HabitWidgetTitle(text: habit.name, size: options.titleSize, wrap: options.wrapTitle, breakWords: options.breakWords)
                    .foregroundStyle(color)
                Spacer(minLength: 0)
                if habit.habit.quantityTracking != nil {
                    HabitDayCell(cell: todayCell, color: color, metrics: metrics)
                } else {
                    Button(intent: MarkHabitTodayIntent(habitName: habit.name)) {
                        HabitDayCell(cell: todayCell, color: color, metrics: metrics)
                    }
                    .buttonStyle(.plain)
                }
            }
            Spacer(minLength: 0)
            HabitGridView(grid: grid, color: color, metrics: metrics, fadesTop: true)
        }
        .widgetAccentable()
    }

    private var todayCell: HabitCell {
        grid.weeks.last?.first { $0.date == today }?.cell ?? .open
    }
}
