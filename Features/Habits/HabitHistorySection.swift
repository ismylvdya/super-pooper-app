import SwiftUI

/// Weeks of the habit back to its first marked day; the newest week is at the bottom and visible first.
/// Tap a day to cycle its mark, long press to pick one. Pulling down at the top adds older weeks
/// (until the page is left). The top edge always fades, the bottom one while newer weeks are below.
struct HabitHistorySection: View {
    @Environment(AppModel.self) private var model
    @Environment(\.tokens) private var tokens
    @Environment(\.rules) private var rules
    let habit: TaskNote
    @State private var addedWeeks = 0
    @State private var width: CGFloat = 320

    var body: some View {
        let context = model.context()
        let today = context.today
        let weeks = HabitGrid.weekCount(for: habit, today: today,
                                        minimumWeeks: rules.habits.historyMinimumWeeks,
                                        extraWeeks: rules.habits.historyExtraWeeks) + addedWeeks
        let grid = HabitGrid(task: habit, weekCount: weeks, today: today, days: context.days)
        let inner = tokens.space(.plateInner)
        let metrics = HabitDotMetrics.fitting(width: width - inner * 2, ringRatio: tokens.size(.habitRingRatio))
        let shape = RoundedRectangle(cornerRadius: tokens.radius(.plate), style: .continuous)
        VStack(alignment: .leading, spacing: 0) {
            PlateHeader(title: "habitPage.history", info: "info.habitPage.history")
            VStack(spacing: 0) {
                WeekdayHeader(metrics: metrics).padding(.top, inner)
                ScrollView {
                    HabitGridView(grid: grid, color: tokens.habitColor(habit), metrics: metrics, onTap: { day in
                        Haptics.play(.light)
                        Task { await model.cycleHabit(habit.name, on: day) }
                    }) { day in
                        HabitDayMenu(habit: habit, day: day, showsDate: true)
                    }
                    .frame(maxWidth: .infinity)
                }
                .contentMargins(.vertical, tokens.size(.fadeHeight) / 2, for: .scrollContent)
                // The newest week is visible first; weeks added on top keep the scroll position.
                .defaultScrollAnchor(.bottom, for: .initialOffset)
                .scrollBounceBehavior(.always)
                .scrollIndicators(.hidden)
                .edgeFades(color: tokens.color(.plateBackground))
                .pullToExtend(icon: .olderWeeks) {
                    Haptics.play(.medium)
                    addedWeeks += rules.habits.historyPullWeeks
                }
                .frame(maxHeight: tokens.size(.habitHistoryMaxHeight))
            }
            .background(tokens.color(.plateBackground), in: shape)
            .clipShape(shape)
            .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { width = $0 }
        }
    }
}
