import SwiftUI

/// Weeks of the habit back to its first marked day; the newest week is at the bottom and visible first.
/// Tap a day to cycle its mark, long press to pick one. Pulling down at the top adds older weeks
/// (until the page is left). At the top the older weeks dissolve completely under the weekday header; the bottom
/// fades in only once the newest week is scrolled down from where it opened.
struct HabitHistorySection: View {
    @Environment(AppModel.self) private var model
    @Environment(\.tokens) private var tokens
    @Environment(\.rules) private var rules
    let habit: TaskNote
    @State private var addedWeeks = 0
    /// The plate's width; the grid is laid out only once it is known, so the scroll starts at the real bottom
    /// (laid out for a guessed width first, the newest week would end up below the plate on a narrow phone).
    @State private var width: CGFloat?

    var body: some View {
        let context = model.context()
        let today = context.today
        let weeks = HabitGrid.weekCount(for: habit, today: today,
                                        minimumWeeks: rules.habits.historyMinimumWeeks,
                                        extraWeeks: rules.habits.historyExtraWeeks) + addedWeeks
        let grid = HabitGrid(task: habit, weekCount: weeks, today: today, days: context.days)
        let inner = tokens.space(.plateInner)
        let shape = RoundedRectangle(cornerRadius: tokens.radius(.plate), style: .continuous)
        VStack(alignment: .leading, spacing: 0) {
            PlateHeader(title: "habitPage.history", info: "info.habitPage.history")
            Group {
                if let width {
                    history(grid, metrics: HabitDotMetrics.fitting(width: width - inner * 2, ringRatio: tokens.size(.habitRingRatio)))
                } else {
                    Color.clear.frame(height: tokens.size(.habitHistoryMaxHeight))
                }
            }
            .frame(maxWidth: .infinity)
            .background(tokens.color(.plateBackground), in: shape)
            .clipShape(shape)
            .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { width = $0 }
        }
    }

    private func history(_ grid: HabitGrid, metrics: HabitDotMetrics) -> some View {
        VStack(spacing: 0) {
                WeekdayHeader(metrics: metrics).padding(.top, tokens.space(.plateInner))
                ScrollView {
                    HabitGridView(grid: grid, color: tokens.habitColor(habit), metrics: metrics, onTap: { day in
                        Haptics.play(.light)
                        Task { await model.cycleHabit(habit.name, on: day) }
                    }) { day in
                        HabitDayMenu(habit: habit, day: day, showsDate: true)
                    }
                    .frame(maxWidth: .infinity)
                    // A margin in the content, not a content margin: those arrive after the scroll is placed at the
                    // bottom and would leave the newest week short of it, under a half-shown fade.
                    .padding(.vertical, tokens.size(.fadeHeight) / 2)
                }
                // The newest week is visible first; weeks added on top keep the scroll position.
                .defaultScrollAnchor(.bottom, for: .initialOffset)
                .scrollBounceBehavior(.always)
                .scrollIndicators(.hidden)
                .edgeFades(color: tokens.color(.plateBackground), solidTop: true)
                .pullToExtend(icon: .olderWeeks) {
                    Haptics.play(.medium)
                    addedWeeks += rules.habits.historyPullWeeks
                }
                .frame(maxHeight: tokens.size(.habitHistoryMaxHeight))
        }
    }
}
