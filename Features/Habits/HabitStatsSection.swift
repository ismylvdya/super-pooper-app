import SwiftUI

/// Soft statistics: this week, streaks, shares of the last 7 / 30 days and all time, counts,
/// and marks by weekday and by month.
struct HabitStatsSection: View {
    @Environment(AppModel.self) private var model
    @Environment(\.tokens) private var tokens
    let habit: TaskNote

    var body: some View {
        let today = model.context().today
        let stats = HabitStats(task: habit, today: today, calendar: model.calendar)
        let color = tokens.habitColor(habit)
        PlateSection(header: "habitPage.stats", info: habit.habit.harmful ? "info.habitPage.stats.harmful" : "info.habitPage.stats") {
            Text(HabitSummary.weekLine(habit, today: today, calendar: model.calendar))
                .font(tokens.font(.rowTitle))
            HStack(alignment: .top) {
                value(streak(stats.currentStreak, unit: stats.streakUnit), "habitPage.stats.current")
                value(streak(stats.longestStreak?.length ?? 0, unit: stats.streakUnit), "habitPage.stats.longest",
                      detail: stats.longestStreak.map(range))
            }
            HStack(alignment: .top) {
                value(percent(stats.last7), "habitPage.stats.last7")
                value(percent(stats.last30), "habitPage.stats.last30")
                value(percent(stats.allTime), "habitPage.stats.allTime")
            }
            HStack(alignment: .top) {
                value("\(stats.doneCount)", "habitPage.stats.done")
                value("\(stats.partialCount)", "habitPage.stats.partial")
                if habit.habit.twiceADay { value("\(stats.twiceCount)", "habitPage.stats.twice") }
            }
            BarRow(title: "habitPage.stats.byWeekday", color: color, bars: Weekday.allCases.map { day in
                (Calendar(identifier: .gregorian).veryShortStandaloneWeekdaySymbols[day.rawValue % 7], stats.byWeekday[day] ?? 0)
            })
            BarRow(title: "habitPage.stats.byMonth", color: color, bars: stats.byMonth.map { month in
                (Calendar(identifier: .gregorian).veryShortStandaloneMonthSymbols[month.month - 1], month.count)
            })
        }
    }

    private func value(_ text: String, _ title: LocalizedStringKey, detail: String? = nil) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(verbatim: text).font(tokens.font(.statValue))
            Text(title).font(tokens.font(.caption)).foregroundStyle(tokens.color(.secondaryText))
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
        return L10n.format("common.range", streak.first.startDate(in: model.calendar).formatted(style),
                           streak.last.startDate(in: model.calendar).formatted(style))
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
            Text(title).font(tokens.font(.caption)).foregroundStyle(tokens.color(.secondaryText))
            HStack(alignment: .bottom, spacing: tokens.space(.habitCellGap)) {
                ForEach(Array(bars.enumerated()), id: \.offset) { _, bar in
                    VStack(spacing: 2) {
                        Text(verbatim: "\(bar.value)").font(tokens.font(.caption)).foregroundStyle(tokens.color(.tertiaryText))
                        RoundedRectangle(cornerRadius: tokens.radius(.habitCell), style: .continuous)
                            .fill(color.opacity(bar.value == 0 ? tokens.opacity(.habitEmpty) : 1))
                            .frame(height: max(tokens.size(.habitStatsBar) * CGFloat(bar.value) / CGFloat(top), 2))
                        Text(verbatim: bar.label).font(tokens.font(.caption)).foregroundStyle(tokens.color(.secondaryText))
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
    }
}
