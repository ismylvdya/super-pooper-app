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
        let color = tokens.habitColor(habit)
        VStack(alignment: .leading, spacing: tokens.space(.habitCellGap) * 2) {
            HStack(alignment: .top, spacing: tokens.space(.chipGap)) {
                Text(habit.name)
                    .font(tokens.font(.widgetTitle))
                    .foregroundStyle(color)
                    .lineLimit(2)
                    .minimumScaleFactor(0.7)
                Spacer(minLength: 0)
                Button(intent: MarkHabitTodayIntent(habitName: habit.name)) {
                    HabitDayCell(cell: todayCell, color: color, isToday: true)
                        .frame(width: tokens.size(.habitDayButton), height: tokens.size(.habitDayButton))
                }
                .buttonStyle(.plain)
            }
            Spacer(minLength: 0)
            HabitGridView(grid: grid, color: color, today: today, fadesTop: true)
        }
        .padding(tokens.space(.widgetPadding))
    }

    private var todayCell: HabitCell {
        let cell = grid.weeks.last?.first { $0.date == today }?.cell ?? .open
        return cell == .notScheduled ? .open : cell
    }
}
