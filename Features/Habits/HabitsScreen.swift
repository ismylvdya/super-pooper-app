import ListEngineChumbulev
import SwiftUI

/// The Habits tab: one list of the list engine — habits first, tasks that simply repeat ("Repeatable tasks") in a section
/// of their own. Before each name today's mark (unmarked, partly, done, twice), a tap cycles it (twice: through all
/// three); a long press lifts the row with today's marks as its menu; rows are carried within their section; a tap
/// opens the habit's page. A habit's name in its own color, bold and rounded; a repeatable task's rounded. No swipes.
/// Pulled down, it syncs. The tab bar's "+" creates a habit.
struct HabitsScreen: View {
    @Environment(AppModel.self) private var model
    @Environment(Router.self) private var router
    @Environment(\.tokens) private var tokens
    @Environment(\.icons) private var icons
    @Environment(\.actions) private var registry
    @Environment(\.openURL) private var openURL
    @State private var pendingAction: PendingAction?

    var body: some View {
        let today = model.context().today
        ReorderableList(sections: Binding(get: { sections(today: today) }, set: moved), look: "lists",
                        actions: { engine(today: today).menu(.habitDay, for: $0) },
                        features: [.carry, .menu, .haptics, .autoscroll, .dim, .scrollIndicator, .wrapTitles], onTap: { router.open(.task($0.id)) },
                        onRefresh: { await model.sync(announce: true) },
                        footer: model.habits.isEmpty ? AnyView(empty) : nil) { item in
            row(item.task, today: today)
        }
        .ignoresSafeArea()
        .actionConfirmation($pendingAction) { handler.run($0) }
        .navigationTitle(Text("tab.habits"))
        .navigationBarTitleDisplayMode(.large)
        .searchOnTitleHold { router.open(.search(.habits)) }
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                PageMoreMenu(search: { router.open(.search(.habits)) }, accessibilityID: "habits.more")
            }
        }
    }

    private static let tracked = "tracked"
    private static let repeatable = "repeatable"

    private func sections(today: LocalDate) -> [ListSection<DayItem>] {
        let groups = HabitGroups(model.habits)
        return [(Self.tracked, "", groups.tracked), (Self.repeatable, L10n.string("habits.repeatable"), groups.repeatable)]
            .filter { !$0.2.isEmpty }
            .map { ListSection(id: $0.0, title: $0.1, items: $0.2.map { DayItem(habit: $0, on: today) }) }
    }

    /// The new order of every habit: the tracked ones, then the repeatable ones.
    private func moved(_ sections: [ListSection<DayItem>]) {
        model.moveHabits(sections.flatMap(\.items).map(\.id))
    }

    /// Today's mark before the name, as far from the name as from the plate's side; a tap cycles it.
    private func row(_ habit: TaskItem, today: LocalDate) -> ListRowContent {
        let mark = HabitMarkIcon.icon(for: habit.dayMark(on: today))
        let rounded = TextStyle(style: "body", weight: habit.habit.repeatable ? .regular : .bold, rounded: true)
        return ListRowContent(title: habit.name, icon: .app(icons[mark]), iconColor: ThemeColor(tokens.habitMarkColor(habit)),
                              iconGap: ListTheme.app.rows.iconMargin - tokens.space(.habitMarkGapLess),
                              onIconTap: habit.habit.quantityTracking == nil ? {
                                  Haptics.play(.mark)
                                  Task { await model.cycleHabit(habit.name, on: today) }
                              } : nil,
                              titleStyle: rounded, titleColor: ThemeColor(tokens.habitNameColor(habit)))
    }

    private var empty: some View {
        PlateHint(text: Text("habits.empty"))
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, ListTheme.app.rows.sideInset)
    }

    /// Today's marks set the mark; the menu's other lines run as in the pool, offering undo.
    private func engine(today: LocalDate) -> EngineActions {
        EngineActions(model: model, tokens: tokens, registry: registry, icons: icons) { action, name in
            Task {
                if action.id.setsHabitMark {
                    await model.setHabitMark(name, on: today, to: action.id.habitMark)
                } else {
                    await model.performOfferingUndo(action, on: name)
                }
            }
        }
    }

    private var handler: TaskActionHandler {
        TaskActionHandler(model: model, router: router, openURL: openURL) { pendingAction = $0 }
    }
}
