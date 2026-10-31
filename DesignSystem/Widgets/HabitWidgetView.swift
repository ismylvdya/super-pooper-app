import AppIntents
import SwiftUI

/// The habit widget: the name in the habit's color, today's day button in the corner (it marks the
/// habit without opening the app) and the last weeks of days at the bottom, the oldest week fading out.
struct HabitWidgetView: View {
    @Environment(\.tokens) private var tokens
    let habit: TaskItem
    let grid: HabitGrid
    let today: LocalDate
    var options = HabitWidgetOptions()

    var body: some View {
        GeometryReader { geometry in
            content(metrics: tokens.habitDots(fitting: geometry.size.width - tokens.space(.widgetPadding) * 2))
        }
    }

    private func content(metrics: HabitDotMetrics) -> some View {
        let color = tokens.habitColor(habit)
        return VStack(alignment: .leading, spacing: tokens.space(.widgetGridGap)) {
            HStack(alignment: .top, spacing: tokens.space(.widgetGap)) {
                HabitWidgetTitle(text: habit.name, size: options.titleSize, wrap: options.wrapTitle, breakWords: options.breakWords)
                    .foregroundStyle(color)
                Spacer(minLength: 0)
                Button(intent: MarkHabitTodayIntent(habitName: habit.name)) {
                    HabitDayCell(cell: todayCell, color: color, metrics: metrics)
                }
                .buttonStyle(.plain)
            }
            Spacer(minLength: 0)
            HabitGridView(grid: grid, color: color, metrics: metrics, fadesTop: true)
        }
        .padding(tokens.space(.widgetPadding))
    }

    private var todayCell: HabitCell {
        grid.weeks.last?.first { $0.date == today }?.cell ?? .open
    }
}
