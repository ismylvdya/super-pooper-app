import SwiftUI

/// A habit in the list: today's day button, the name in the habit's color (bold), its routine, Twice and reminders.
struct HabitRow: View {
    @Environment(AppModel.self) var model
    @Environment(Router.self) private var router
    @Environment(\.tokens) var tokens
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
                // Every row is as tall as one with a detail line; a name without one stands in the middle of that height.
                VStack(alignment: .leading, spacing: tokens.space(.titleDetailGap)) {
                    Text(habit.name).font(tokens.font(nameFont)).foregroundStyle(tokens.habitNameColor(habit)).lineLimit(2)
                    detail
                }
                .frame(maxWidth: .infinity, minHeight: HabitRowHeight.text(name: tokens.uiFont(nameFont).lineHeight,
                                                                          gap: tokens.space(.titleDetailGap),
                                                                          detail: tokens.uiFont(Self.detailFont).lineHeight),
                       alignment: .leading)
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
    static let detailFont: FontToken = .hint

    private var nameFont: FontToken { habit.habit.repeatable ? .repeatableTitle : .habitTitle }

    /// The routine and Twice as one line ("Morning · Twice"), then, after the same separator, a bell per reminder as tall
    /// as the line's capital letters; nothing when the habit has none.
    @ViewBuilder var detail: some View {
        let bells = HabitSummary.bellCount(habit, limit: model.config.rules.habits.maxListBells)
        let traits = HabitSummary.traitsLine(habit, bellsFollow: bells > 0)
        if traits != nil || bells > 0 {
            HStack(alignment: .firstTextBaseline, spacing: 0) {
                if let traits {
                    Text(verbatim: traits.text)
                        .accessibilityLabel(Text(verbatim: traits.spoken))
                        .accessibilityIdentifier("habitTraits:\(habit.name)")
                }
                HStack(alignment: .firstTextBaseline, spacing: tokens.space(.badgeGap)) {
                    ForEach(0..<bells, id: \.self) { _ in CapHeightIcon(.bell, font: Self.detailFont) }
                }
                .accessibilityIdentifier("habitBells:\(habit.name)")
            }
            .secondaryText(Self.detailFont)
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
        // A wide plate (the phone sideways) has large grid dots: their ring would nearly fill this small circle.
        return .cell(own.cell, ring: min(grid.ring, own.ring))
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
