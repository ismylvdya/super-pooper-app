import SwiftUI

/// The Habits tab: every active habit with today's mark (tap cycles, long press picks), its week
/// progress, a page per habit; "+" creates a habit, rows reorder by dragging, the archive is at the bottom.
struct HabitsScreen: View {
    @Environment(AppModel.self) private var model
    @Environment(Router.self) private var router
    @Environment(\.tokens) private var tokens
    @Environment(\.icons) private var icons

    var body: some View {
        let today = model.context().today
        List {
            Text("tab.habits")
                .font(tokens.font(.pageTitle))
                .frame(maxWidth: .infinity)
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets())
            if model.habits.isEmpty {
                Text("habits.empty").font(tokens.font(.hint)).foregroundStyle(tokens.color(.secondaryText))
                    .listRowBackground(Color.clear)
            }
            Section {
                ForEach(model.habits, id: \.name) { habit in
                    HabitRow(habit: habit, today: today)
                        // The row fills its cell, so a long press lifts the whole plate.
                        .listRowInsets(EdgeInsets())
                        .listRowBackground(tokens.color(.plateBackground))
                }
                .onMove { source, destination in
                    var names = model.habits.map(\.name)
                    names.move(fromOffsets: source, toOffset: destination)
                    Haptics.play(.medium)
                    model.moveHabits(names)
                }
            }
            Section {
                NavigationLink(value: Route.routines) {
                    PlateRow(icon: .timeOfDay, title: "routines.title")
                }
                .listRowInsets(EdgeInsets(top: 0, leading: tokens.space(.listRowInset), bottom: 0, trailing: tokens.space(.listRowInset)))
                .listRowBackground(tokens.color(.plateBackground))
            }

        }
        .scrollContentBackground(.hidden)
        .background(tokens.color(.screenBackground))
        .refreshable { await model.sync(announce: true) }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { router.open(.newHabit) } label: { Image(systemName: icons[.newTask]) }
                    .tint(tokens.color(.accent))
                    .accessibilityLabel(Text("habits.new"))
                    .accessibilityIdentifier("habits.new")
            }
        }
    }
}

/// A habit in the list: today's day button, the name in the habit's color, this week's progress.
struct HabitRow: View {
    @Environment(AppModel.self) private var model
    @Environment(\.tokens) private var tokens
    let habit: TaskNote
    let today: LocalDate

    var body: some View {
        HStack(spacing: tokens.space(.iconTextGap)) {
            // The mark sits in the icon column of the other plates, its circle as wide as an icon;
            // the outer ring of Twice may reach past it.
            HabitDayButton(habit: habit, day: today)
                .frame(width: tokens.size(.iconColumn))
            NavigationLink(value: Route.task(habit.name)) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(habit.name).foregroundStyle(tokens.habitColor(habit)).lineLimit(2)
                    Text(HabitSummary.weekLine(habit, today: today, calendar: model.calendar))
                        .font(tokens.font(.hint)).foregroundStyle(tokens.color(.secondaryText))
                }
            }
        }
        .padding(.horizontal, tokens.space(.listRowInset))
        .padding(.vertical, tokens.space(.rowVertical) / 2)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(tokens.color(.plateBackground))
        // A long press lifts the whole row and offers today's marks.
        .contentShape(.contextMenuPreview, Rectangle())
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
        let grid = HabitGrid(task: habit, weekCount: 1, today: day, calendar: model.calendar)
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

/// Long-press menu of a habit's day, the same as a habit's menu in the pool (`actions.json` → `habitDay`): the
/// marks with their images, the current one not selectable. In the history the day is named ("17 Sep 2026").
struct HabitDayMenu: View {
    @Environment(AppModel.self) private var model
    let habit: TaskNote
    let day: LocalDate
    var showsDate = false

    var body: some View {
        if showsDate {
            Text(day.startDate(in: model.calendar).formatted(.dateTime.day().month(.abbreviated).year()))
        }
        let state = HabitInstances(task: habit).mark(on: day).map(DayItemState.marked) ?? .open
        ActionMenuContent(menu: .habitDay, item: DayItem(task: habit, state: state, blockers: [], problems: [])) { action in
            Task { await model.setHabitMark(habit.name, on: day, to: AppModel.habitMark(for: action.id)) }
        }
    }
}
