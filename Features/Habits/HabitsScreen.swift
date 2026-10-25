import SwiftUI

/// The Habits tab: every active habit with today's mark (tap cycles, long press picks), its week
/// progress, a page per habit; "+" creates a habit, rows reorder by dragging, the archive is at the bottom.
struct HabitsScreen: View {
    @Environment(AppModel.self) private var model
    @Environment(Router.self) private var router
    @Environment(\.tokens) private var tokens
    @Environment(\.icons) private var icons
    @State private var isLargeTitleVisible = true

    var body: some View {
        let today = model.context().today
        List {
            Text("tab.habits")
                .font(tokens.font(.pageTitle))
                .frame(maxWidth: .infinity)
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets())
                .tracksLargeTitle($isLargeTitleVisible)
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
        .barTitle(L10n.string("tab.habits"), isHidden: isLargeTitleVisible)
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
