import AppIntents
import SwiftUI

/// The habit widget: the name in the habit's color, today's day button in the corner (it marks the
/// habit without opening the app) and the last weeks of days at the bottom, the oldest week fading out.
struct HabitWidgetView: View {
    @Environment(\.tokens) private var tokens
    let habit: TaskNote
    let grid: HabitGrid
    let today: LocalDate
    var options = HabitWidgetOptions()

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
                HabitWidgetTitle(text: habit.name, size: options.titleSize ?? Double(tokens.uiFont(.widgetTitle).pointSize),
                                 wrap: options.wrapTitle, breakWords: options.breakWords)
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

/// The widget title: one line that fades out; with "Wrap Title" a title that does not fit goes to two
/// lines a third smaller, by words or (with "Break Words") by letters with a hyphen.
struct HabitWidgetTitle: View {
    let text: String
    let size: Double
    var wrap = false
    var breakWords = false

    var body: some View {
        let font = Font.system(size: size, weight: .semibold, design: .rounded)
        let small = size * 2 / 3
        let smallFont = Font.system(size: small, weight: .semibold, design: .rounded)
        let smallLine = UIFont.systemFont(ofSize: small, weight: .semibold).lineHeight
        if wrap {
            ViewThatFits(in: .horizontal) {
                Text(text).font(font).lineLimit(1).fixedSize()
                if breakWords {
                    GeometryReader { geometry in
                        let lines = HyphenSplit.split(text, width: geometry.size.width,
                                                      font: UIFont.systemFont(ofSize: small, weight: .semibold))
                        VStack(alignment: .leading, spacing: 0) {
                            Text(lines.first).font(smallFont).lineLimit(1)
                            FadingText(text: lines.rest, font: smallFont, lineHeight: smallLine)
                        }
                    }
                    .frame(height: smallLine * 2)
                } else {
                    FadingText(text: text, font: smallFont, lineHeight: smallLine, lines: 2)
                }
            }
        } else {
            FadingText(text: text, font: font, lineHeight: UIFont.systemFont(ofSize: size, weight: .semibold).lineHeight)
        }
    }
}
