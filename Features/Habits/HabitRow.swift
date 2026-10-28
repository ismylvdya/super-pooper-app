import SwiftUI

/// A habit in the list: today's day button, the name in the habit's color (bold), its routine, Twice and reminders.
struct HabitRow: View {
    @Environment(AppModel.self) var model
    @Environment(Router.self) private var router
    @Environment(\.tokens) var tokens
    @Environment(\.icons) var icons
    let habit: TaskNote
    let today: LocalDate
    /// The row's plate width: the history grid of a plate this wide sets the day mark's ring and gap.
    @State private var plateWidth: CGFloat?

    var body: some View {
        HStack(spacing: tokens.space(.iconTextGap)) {
            // The mark sits in the icon column of the other plates, its circle as wide as an icon;
            // the outer ring of Twice may reach past it.
            HabitDayButton(habit: habit, day: today, plateWidth: plateWidth)
                .frame(width: tokens.size(.iconColumn))
            // A button with the app's chevron, as the rows of the other tabs' plates (a list's link has its own).
            Button { router.open(.task(habit.name)) } label: {
                HStack(spacing: tokens.space(.iconTextGap)) {
                    VStack(alignment: .leading, spacing: tokens.space(.titleDetailGap)) {
                        Text(habit.name).font(tokens.font(habit.habit.repeatable ? .repeatableTitle : .habitTitle)).foregroundStyle(tokens.habitNameColor(habit)).lineLimit(2)
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
        .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { plateWidth = $0 }
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
                ForEach(0..<bells, id: \.self) { _ in Image(systemName: icons[.bell]) }
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
    var plateWidth: CGFloat?

    /// The ring and the gap of Twice as thick as in the habit's history grid; the dot inside is smaller instead.
    private var metrics: HabitDotMetrics {
        let ratio = tokens.size(.habitRingRatio)
        let own = HabitDotMetrics(dot: tokens.size(.iconColumn), ringRatio: ratio)
        guard let plateWidth else { return own }
        let grid = HabitDotMetrics.fitting(width: plateWidth - tokens.space(.plateInner) * 2, ringRatio: ratio)
        return .cell(own.cell, ring: grid.ring)
    }

    var body: some View {
        let grid = HabitGrid(task: habit, weekCount: 1, today: day, days: model.context().days)
        let cell = grid.weeks.last?.first { $0.date == day }?.cell ?? .open
        HabitDayCell(cell: cell, color: tokens.habitMarkColor(habit), metrics: metrics)
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
