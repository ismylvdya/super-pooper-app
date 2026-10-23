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
                        .listRowBackground(tokens.color(.plateBackground))
                }
                .onMove { source, destination in
                    var names = model.habits.map(\.name)
                    names.move(fromOffsets: source, toOffset: destination)
                    Haptics.play(.medium)
                    model.moveHabits(names)
                }
            }
            if !model.archivedHabits.isEmpty {
                Section {
                    NavigationLink(value: Route.habitArchive) {
                        Label(L10n.format("habits.archive", model.archivedHabits.count), systemImage: icons[.archive])
                    }
                    .listRowBackground(tokens.color(.plateBackground))
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(tokens.color(.screenBackground))
        .refreshable { await model.sync(announce: true) }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { router.open(.newHabit) } label: { Image(systemName: icons[.newTask]) }
                    .tint(.primary)
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
            HabitDayButton(habit: habit, day: today)
            NavigationLink(value: Route.task(habit.name)) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(habit.name).foregroundStyle(tokens.habitColor(habit)).lineLimit(2)
                    Text(HabitSummary.weekLine(habit, today: today, calendar: model.calendar))
                        .font(tokens.font(.hint)).foregroundStyle(tokens.color(.secondaryText))
                }
            }
        }
        .accessibilityIdentifier("habit:\(habit.name)")
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
        HabitDayCell(cell: cell == .notScheduled ? .open : cell, color: tokens.habitColor(habit), isToday: true)
            .frame(width: tokens.size(.habitDayButton), height: tokens.size(.habitDayButton))
            .contentShape(Rectangle())
            .onTapGesture {
                Haptics.play(.light)
                Task { await model.cycleHabit(habit.name, on: day) }
            }
            .contextMenu { HabitDayMenu(habit: habit, day: day) }
            .accessibilityAddTraits(.isButton)
            .accessibilityLabel(Text("habits.markToday"))
            .accessibilityIdentifier("habitDay:\(habit.name)")
    }
}

/// Long-press menu of a habit's day: the date, then Done / Partially / Twice (twice-a-day habits) / Clear.
struct HabitDayMenu: View {
    @Environment(AppModel.self) private var model
    @Environment(\.actions) private var actions
    let habit: TaskNote
    let day: LocalDate

    var body: some View {
        let current = HabitInstances(task: habit).mark(on: day)
        Text(day.startDate(in: model.calendar).formatted(date: .complete, time: .omitted))
        ForEach(marks, id: \.self) { mark in
            let action = actions.definition(Self.actionID(mark))
            Button { set(mark) } label: { Label(LocalizedStringKey(action.title), systemImage: action.icon) }
                .disabled(current == mark)
        }
        if current != nil {
            let action = actions.definition(.unmark)
            Button { set(nil) } label: { Label(LocalizedStringKey(action.title), systemImage: action.icon) }
        }
    }

    private var marks: [HabitMark] { habit.habit.twiceADay ? [.done, .partial, .twice] : [.done, .partial] }

    private func set(_ mark: HabitMark?) {
        Haptics.play(.light)
        Task { await model.setHabitMark(habit.name, on: day, to: mark) }
    }

    static func actionID(_ mark: HabitMark) -> ActionID {
        switch mark {
        case .done: .done
        case .partial: .partial
        case .twice: .twice
        }
    }
}
