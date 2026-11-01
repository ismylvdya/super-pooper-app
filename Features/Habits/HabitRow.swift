import SwiftUI

/// A habit in the list: today's day button, the name in the habit's color (bold), its routine, Twice and reminders.
struct HabitRow: View {
    @Environment(AppModel.self) var model
    @Environment(Router.self) private var router
    @Environment(\.tokens) var tokens
    @Environment(\.icons) var icons
    let habit: TaskItem
    let today: LocalDate
    /// The width inside the row's plate: the history grid of a plate this wide sets the day mark's ring and gap.
    @State private var innerWidth: CGFloat?

    var body: some View {
        HStack(spacing: tokens.space(.iconTextGap)) {
            // The mark sits in the icon column of the other plates, its circle as wide as an icon;
            // the outer ring of Twice may reach past it.
            HabitDayButton(habit: habit, day: today, innerWidth: innerWidth)
                .frame(width: tokens.size(.iconColumn))
            // A tap opens the page, as on the rows of Soon; with the app's chevron (a list's link has its own). Not a
            // button: a button has a pressed look of its own, which a long press may leave on the row after its menu
            // has closed.
            HStack(spacing: tokens.space(.iconTextGap)) {
                VStack(alignment: .leading, spacing: tokens.space(.titleDetailGap)) {
                    Text(habit.name).font(tokens.font(habit.habit.repeatable ? .repeatableTitle : .habitTitle)).foregroundStyle(tokens.habitNameColor(habit)).lineLimit(2)
                    detail
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                DisclosureAccessory()
            }
            .contentShape(Rectangle())
            .onTapGesture { router.open(.task(habit.name)) }
            .accessibilityElement(children: .combine)
            .accessibilityAddTraits(.isButton)
            .accessibilityIdentifier("habit:\(habit.name)")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { innerWidth = $0 }
    }
}

extension HabitRow {
    /// The routine and Twice as one line ("Morning · Twice"), then a bell per reminder; nothing when the habit has none.
    @ViewBuilder var detail: some View {
        let traits = HabitSummary.traitsLine(habit)
        let bells = HabitSummary.bellCount(habit, limit: model.config.rules.habits.maxListBells)
        if traits != nil || bells > 0 {
            HStack(spacing: tokens.space(.badgeGap)) {
                if let traits {
                    Text(verbatim: traits.text)
                        .accessibilityLabel(Text(verbatim: traits.spoken))
                        .accessibilityIdentifier("habitTraits:\(habit.name)")
                }
                ForEach(0..<bells, id: \.self) { _ in Image(systemName: icons[.bell]) }
            }
            .secondaryText(.hint)
        }
    }
}

/// The square of one day of a habit: tap cycles the mark, long press offers every mark.
struct HabitDayButton: View {
    @Environment(AppModel.self) private var model
    @Environment(\.tokens) private var tokens
    let habit: TaskItem
    let day: LocalDate
    /// The width inside the row's plate (nil until measured).
    var innerWidth: CGFloat?

    /// The ring and the gap of Twice as thick as in the habit's history grid; the dot inside is smaller instead.
    private var metrics: HabitDotMetrics {
        let ratio = tokens.ratio(.habitRing)
        let own = HabitDotMetrics(dot: tokens.size(.iconColumn), ringRatio: ratio)
        guard let innerWidth else { return own }
        let grid = tokens.habitDots(fitting: innerWidth)
        return .cell(own.cell, ring: grid.ring)
    }

    var body: some View {
        let grid = HabitGrid(task: habit, weekCount: 1, today: day, days: model.context().days)
        let cell = grid.weeks.last?.first { $0.date == day }?.cell ?? .open
        HabitDayCell(cell: cell, color: tokens.habitMarkColor(habit), metrics: metrics)
            .contentShape(Circle())
            .onTapGesture {
                Haptics.play(.mark)
                Task { await model.cycleHabit(habit.name, on: day) }
            }
            .accessibilityAddTraits(.isButton)
            .accessibilityLabel(Text("habits.markToday"))
            .accessibilityIdentifier("habitDay:\(habit.name)")
    }
}
