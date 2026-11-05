import SwiftUI

/// Soft statistics: streaks, shares of the recent periods (`habits.stats.shareWindowsDays`) and all time,
/// counts, and marks by weekday and by month.
struct HabitStatsSection: View {
    @Environment(AppModel.self) private var model
    @Environment(\.tokens) private var tokens
    @Environment(\.rules) private var rules
    let habit: TaskItem

    var body: some View {
        let context = model.context()
        let today = context.today
        let stats = HabitStats(task: habit, today: today, days: context.days, rules: rules.habits.stats)
        let color = tokens.habitColor(habit)
        PlateSection(header: "habitPage.stats", info: habit.habit.harmful ? "info.habitPage.stats.harmful" : "info.habitPage.stats") {
            HStack(alignment: .top) {
                value(streak(stats.currentStreak, unit: stats.streakUnit), "habitPage.stats.current")
                value(streak(stats.longestStreak?.length ?? 0, unit: stats.streakUnit), "habitPage.stats.longest",
                      detail: stats.longestStreak.map(range))
            }
            HStack(alignment: .top) {
                ForEach(stats.recentShares, id: \.days) { recent in
                    value(percent(recent.share), title: L10n.format("habitPage.stats.lastDays", recent.days))
                }
                value(percent(stats.allTime), "habitPage.stats.allTime")
            }
            HStack(alignment: .top) {
                value("\(stats.doneCount)", "habitPage.stats.done")
                value("\(stats.partialCount)", "habitPage.stats.partial")
                if habit.isTwiceADay { value("\(stats.twiceCount)", "habitPage.stats.twice") }
            }
            BarRow(title: "habitPage.stats.byWeekday", color: color, bars: Weekday.allCases.map { day in
                (day.name(.initial, in: model.calendar), stats.byWeekday[day] ?? 0)
            })
            MonthBars(title: "habitPage.stats.byMonth", color: color, months: stats.byMonth.map { month in
                (MonthName.full(month.month, in: model.calendar), month.count)
            })
        }
    }

    private func value(_ text: String, _ title: LocalizedStringKey, detail: String? = nil) -> some View {
        value(text, title: Text(title), detail: detail)
    }

    private func value(_ text: String, title: String) -> some View {
        value(text, title: Text(verbatim: title), detail: nil)
    }

    private func value(_ text: String, title: Text, detail: String?) -> some View {
        VStack(alignment: .leading, spacing: tokens.space(.titleDetailGap)) {
            Text(verbatim: text).font(tokens.font(.statValue))
            title.secondaryText()
            if let detail { Text(verbatim: detail).font(tokens.font(.caption)).foregroundStyle(tokens.color(.tertiaryText)) }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func streak(_ length: Int, unit: HabitStats.StreakUnit) -> String {
        L10n.format(unit == .weeks ? "habitPage.stats.weeks" : "habitPage.stats.days", length)
    }

    private func percent(_ share: Double?) -> String {
        share.map { $0.formatted(.percent.precision(.fractionLength(0))) } ?? L10n.string("common.noValue")
    }

    private func range(_ streak: HabitStats.Streak) -> String {
        let style = Date.FormatStyle().day().month(.abbreviated)
        return L10n.format("common.range", DateText.format(streak.first, style, calendar: model.calendar),
                           DateText.format(streak.last, style, calendar: model.calendar))
    }
}

/// A titled row of small bars with a label under each.
struct BarRow: View {
    @Environment(\.tokens) private var tokens
    let title: LocalizedStringKey
    let color: Color
    let bars: [(label: String, value: Int)]

    var body: some View {
        let top = max(bars.map(\.value).max() ?? 0, 1)
        VStack(alignment: .leading, spacing: tokens.space(.chipGap)) {
            Text(title).secondaryText()
            HStack(alignment: .bottom, spacing: tokens.space(.habitCellGap)) {
                ForEach(Array(bars.enumerated()), id: \.offset) { _, bar in
                    VStack(spacing: tokens.space(.titleDetailGap)) {
                        Text(verbatim: "\(bar.value)").font(tokens.font(.caption)).foregroundStyle(tokens.color(.tertiaryText))
                        RoundedRectangle(cornerRadius: tokens.radius(.habitCell), style: .continuous)
                            .fill(color.opacity(bar.value == 0 ? tokens.opacity(.habitEmpty) : 1))
                            .frame(height: max(tokens.size(.habitStatsBar) * CGFloat(bar.value) / CGFloat(top), 2))
                        Text(verbatim: bar.label).secondaryText()
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
    }
}
