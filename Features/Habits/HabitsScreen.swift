import SwiftUI

/// The Habits tab: every active habit with today's mark (tap cycles, long press picks, a swipe to the right is Done, to
/// the left Delete), a page per habit; the tab bar's "+" creates a habit, rows reorder by dragging inside their group. Habits come first,
/// tasks that simply repeat ("Repeatable tasks") in a group of their own. A plain list whose rows draw the app's
/// plates themselves, so the title, the corners and the gaps match the other tabs' pages.
struct HabitsScreen: View {
    @Environment(AppModel.self) private var model
    @Environment(Router.self) private var router
    @Environment(\.tokens) private var tokens
    @Environment(\.openURL) private var openURL
    @State private var titleHeight: CGFloat = 0
    @State private var pendingAction: PendingAction?
    @State private var query = ""
    @State private var isSearching = false
    @State private var frames = ListGroupFrames()

    var body: some View {
        let today = model.context().today
        let groups = HabitGroups(model.habits.filter { SearchMatcher.matches($0.name, query) })
        List {
            LargePageTitle(isNested: false, height: $titleHeight) { Text("tab.habits") }
                .listGroupSpacer()
            if model.habits.isEmpty {
                Text("habits.empty").secondaryText(.hint)
                    .listGroupSpacer()
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
            .listGroupSpacer()
        }
        .listGroupStyle()
        .listGroupBacking(frames)
        .titleScrollsIntoBar(L10n.string("tab.habits"), titleHeight: titleHeight)
        .appList()
        // The title starts where the other tabs' page titles start, not under the list's own top margin.
        .contentMargins(.top, 0, for: .scrollContent)
        .pageSearch(query: $query, isSearching: $isSearching, prompt: "search.prompt.tasks")
        .syncsOnPull()
        .actionConfirmation($pendingAction) { handler.run($0) }
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                SearchBarButton(isSearching: $isSearching, accessibilityID: "habits.search")
            }
        }
    }

    private var handler: TaskActionHandler {
        TaskActionHandler(model: model, router: router, openURL: openURL) { pendingAction = $0 }
    }

    /// The space between two plates of the page.
    private var gap: some View {
        Color.clear.frame(height: tokens.space(.groupGap)).listGroupSpacer()
    }

    /// One group of rows; the rounded corners belong to its first and last row, as on every plate.
    @ViewBuilder private func group(_ habits: [TaskItem], header: LocalizedStringKey?, groups: HabitGroups, isRepeatable: Bool,
                                    today: LocalDate) -> some View {
        if !habits.isEmpty {
            if let header { ListGroupHeader(title: Text(header)) } else { gap }
            ForEach(Array(habits.enumerated()), id: \.element.name) { index, habit in
                HabitRow(habit: habit, today: today)
                    .listGroupRow(group: isRepeatable ? "repeatable" : "tracked", id: habit.name, index: index, count: habits.count,
                                  frames: frames, vertical: tokens.space(.rowVertical) / 2,
                                  separatorIndent: tokens.size(.iconColumn) + tokens.space(.iconTextGap)) {
                        // A long press lifts the row and offers today's marks.
                        HabitDayMenu(habit: habit, day: today)
                    }
                    .actionSwipes(.habit, item: DayItem(habit: habit, on: today)) { handler.handle($0, taskName: habit.name) }
            }
            // While a search filters the list the rows cannot move: the order is the order of every habit.
            .onMove(perform: query.isEmpty ? { source, destination in
                Haptics.play(.reorder)
                model.moveHabits(groups.order(moving: source, to: destination, inRepeatable: isRepeatable))
            } : nil)
        }
    }
}

