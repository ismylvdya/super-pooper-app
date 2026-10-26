import SwiftUI

/// A habit in the list: today's day button, the name in the habit's color, this week's progress.
struct HabitRow: View {
    @Environment(AppModel.self) private var model
    @Environment(Router.self) private var router
    @Environment(\.tokens) private var tokens
    let habit: TaskNote
    let today: LocalDate
    var isFirst = true
    var isLast = true

    var body: some View {
        HStack(spacing: tokens.space(.iconTextGap)) {
            // The mark sits in the icon column of the other plates, its circle as wide as an icon;
            // the outer ring of Twice may reach past it.
            HabitDayButton(habit: habit, day: today)
                .frame(width: tokens.size(.iconColumn))
            // A button with the app's chevron, as the rows of the other tabs' plates (a list's link has its own).
            Button { router.open(.task(habit.name)) } label: {
                HStack(spacing: tokens.space(.iconTextGap)) {
                    TitleDetailLabel(detail: Text(HabitSummary.weekLine(habit, today: today, days: model.context().days))) {
                        Text(habit.name).font(tokens.font(.habitTitle)).foregroundStyle(tokens.habitColor(habit)).lineLimit(2)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    DisclosureAccessory()
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("habit:\(habit.name)")
        }
        .padding(.horizontal, tokens.space(.plateInner))
        .padding(.vertical, tokens.space(.rowVertical) / 2)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(GroupRowBackground(isFirst: isFirst, isLast: isLast))
        // A long press lifts the whole row (with its group's corners) and offers today's marks.
        .contentShape(.contextMenuPreview, GroupRowBackground.shape(isFirst: isFirst, isLast: isLast, radius: tokens.radius(.plate)))
        .contextMenu { HabitDayMenu(habit: habit, day: today) }
    }
}

/// The square of one day of a habit: tap cycles the mark, long press offers every mark.
struct HabitDayButton: View {
    @Environment(AppModel.self) private var model
    @Environment(\.tokens) private var tokens
    let habit: TaskNote
    let day: LocalDate

    var body: some View {
        let grid = HabitGrid(task: habit, weekCount: 1, today: day, days: model.context().days)
        let cell = grid.weeks.last?.first { $0.date == day }?.cell ?? .open
        let metrics = HabitDotMetrics(dot: tokens.size(.iconColumn), ringRatio: tokens.size(.habitRingRatio))
        HabitDayCell(cell: cell, color: tokens.habitColor(habit), metrics: metrics)
            .contentShape(Circle())
            .onTapGesture {
                Haptics.play(.light)
                Task { await model.cycleHabit(habit.name, on: day) }
            }
            .accessibilityAddTraits(.isButton)
            .accessibilityLabel(Text("habits.markToday"))
            .accessibilityIdentifier("habitDay:\(habit.name)")
    }
}
