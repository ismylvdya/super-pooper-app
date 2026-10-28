import SwiftUI

/// The Habits tab: every active habit with today's mark (tap cycles, long press picks), its week
/// progress, a page per habit; "+" creates a habit, rows reorder by dragging inside their group. Habits come first,
/// tasks that simply repeat ("Repeatable tasks") in a group of their own. A plain list whose rows draw the app's
/// plates themselves, so the title, the corners and the gaps match the other tabs' pages.
struct HabitsScreen: View {
    @Environment(AppModel.self) private var model
    @Environment(Router.self) private var router
    @Environment(\.tokens) private var tokens
    @Environment(\.icons) private var icons
    @State private var isLargeTitleVisible = true
    @State private var titleHeight: CGFloat = 0
    @State private var query = ""
    @State private var isSearching = false

    var body: some View {
        let today = model.context().today
        let groups = HabitGroups(model.habits.filter { SearchMatcher.matches($0.name, query) })
        List {
            Text("tab.habits")
                .font(tokens.font(.pageTitle))
                .frame(maxWidth: .infinity)
                .padding(.top, tokens.space(.nestedTitleLift))
                .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { titleHeight = $0 }
                .pageCell()
            if model.habits.isEmpty {
                Text("habits.empty").font(tokens.font(.hint)).foregroundStyle(tokens.color(.secondaryText))
                    .pageCell()
            }
            group(groups.tracked, header: nil, groups: groups, isRepeatable: false, today: today)
            group(groups.repeatable, header: "habits.repeatable", groups: groups, isRepeatable: true, today: today)
            gap
            // The same plate and row as on the Lists tab.
            Plate {
                Button { router.open(.routines) } label: {
                    PlateRow(icon: .timeOfDay, title: "routines.title") { DisclosureAccessory() }
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("habits.routines")
            }
            .pageCell()
        }
        .listStyle(.plain)
        .tracksLargeTitle($isLargeTitleVisible, titleHeight: titleHeight)
        // The screen margins belong to the list, not to its cells: a lifted or dragged row is only its plate.
        .contentMargins(.horizontal, tokens.space(.screenHorizontal), for: .scrollContent)
        // Gaps are rows of their own height, not of a list row's minimum.
        .environment(\.defaultMinListRowHeight, 0)
        .appList()
        // The title starts where the other tabs' page titles start, not under the list's own top margin.
        .contentMargins(.top, 0, for: .scrollContent)
        .pageSearch(query: $query, isSearching: $isSearching, prompt: "search.prompt.tasks")
        .refreshable { await model.sync(announce: true) }
        .barTitle(L10n.string("tab.habits"), isHidden: isLargeTitleVisible)
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                Button { router.open(.newHabit) } label: { Image(systemName: icons[.newTask]) }
                    .tint(tokens.color(.accent))
                    .accessibilityLabel(Text("habits.new"))
                    .accessibilityIdentifier("habits.new")
                SearchBarButton(isSearching: $isSearching, accessibilityID: "habits.search")
            }
        }
    }

    /// The space between two plates of the page.
    private var gap: some View {
        Color.clear.frame(height: tokens.space(.groupGap)).pageCell()
    }

    /// One group of rows; the rounded corners belong to its first and last row, as on every plate.
    @ViewBuilder private func group(_ habits: [TaskNote], header: LocalizedStringKey?, groups: HabitGroups, isRepeatable: Bool,
                                    today: LocalDate) -> some View {
        if !habits.isEmpty {
            gap
            if let header {
                Text(header)
                    .font(tokens.font(.sectionHeader))
                    .foregroundStyle(tokens.color(.tertiaryText))
                    .padding(.horizontal, tokens.space(.plateInner))
                    .padding(.bottom, tokens.space(.headerToPlate))
                    .pageCell()
            }
            ForEach(Array(habits.enumerated()), id: \.element.name) { index, habit in
                let isFirst = index == 0, isLast = index == habits.count - 1
                HabitRow(habit: habit, today: today, isFirst: isFirst, isLast: isLast)
                    .pageCell()
                    // Rebuilt when it becomes or stops being first or last, so the corners follow a new order.
                    .id("\(habit.name)|\(isFirst)|\(isLast)")
            }
            // While a search filters the list the rows cannot move: the order is the order of every habit.
            .onMove(perform: query.isEmpty ? { source, destination in
                Haptics.play(.medium)
                model.moveHabits(groups.order(moving: source, to: destination, inRepeatable: isRepeatable))
            } : nil)
        }
    }
}

private extension View {
    /// A row of the plain list that draws its own plate: no inset, background or separator from the list.
    func pageCell() -> some View {
        listRowInsets(EdgeInsets())
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
    }
}
