import AppIntents
import SwiftUI

/// The habit widget: the name in the habit's color, today's day button in the corner (it marks the
/// habit without opening the app) and the last weeks of days at the bottom, the oldest week fading out.
struct HabitWidgetView: View {
    @Environment(\.tokens) private var tokens
    let habit: TaskNote
    let grid: HabitGrid
    let today: LocalDate

    var body: some View {
        GeometryReader { geometry in
            content(metrics: HabitDotMetrics.fitting(width: geometry.size.width - tokens.space(.widgetPadding) * 2,
                                                     ringRatio: tokens.size(.habitRingRatio)))
        }
    }

    private func content(metrics: HabitDotMetrics) -> some View {
        let color = tokens.habitColor(habit)
        return VStack(alignment: .leading, spacing: tokens.space(.habitCellGap) * 2) {
            HStack(alignment: .top, spacing: tokens.space(.chipGap)) {
                Text(habit.name)
                    .font(tokens.font(.widgetTitle))
                    .foregroundStyle(color)
                    .lineLimit(2)
                    .minimumScaleFactor(0.7)
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
