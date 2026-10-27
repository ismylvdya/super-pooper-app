import SwiftUI

/// A habit in the list: today's day button, the name in the habit's color (bold), its routine, Twice and reminders.
struct HabitRow: View {
    @Environment(AppModel.self) var model
    @Environment(Router.self) private var router
    @Environment(\.tokens) var tokens
    @Environment(\.icons) var icons
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
                    VStack(alignment: .leading, spacing: tokens.space(.titleDetailGap)) {
                        Text(habit.name).font(tokens.font(.habitTitle)).foregroundStyle(tokens.habitNameColor(habit)).lineLimit(2)
                        detail
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
        // A long press lifts the row as a whole plate and offers today's marks.
        .liftedPlate()
        .contextMenu { HabitDayMenu(habit: habit, day: today) }
    }
}

extension HabitRow {
    /// The routine, Twice and a bell per reminder under the name; nothing when the habit has none of them.
    @ViewBuilder var detail: some View {
        let traits = HabitSummary.traits(habit)
        let bells = HabitSummary.bellCount(habit, limit: model.config.rules.habits.maxListBells)
        if !traits.isEmpty || bells > 0 {
            HStack(spacing: tokens.space(.badgeGap)) {
                if !traits.isEmpty { Text(traits) }
                ForEach(0..<bells, id: \.self) { _ in Image(systemName: icons[.reminder]) }
            }
            .font(tokens.font(.hint))
            .foregroundStyle(tokens.color(.secondaryText))
        }
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
