import ListEngineChumbulev
import SwiftUI

/// Spreader (the morning review; D-188): the pool as a table — one row per task with property chips edited in place, in
/// Morning, Day and Evening groups; rows reorder by dragging, also into another group (which sets their part of the day).
/// Reset sort, in the bar's "…", brings the pool's rules back. Tapping a row (outside its chips) opens the task page.
/// A long press opens the same menu as the row in the pool (and moving the finger then drags the row).
/// Swiping a row right moves it a tab right or left; swiping it left has one button: a task's Not today, a habit's Skip
/// today. What was taken out of today waits in the Not today group at the bottom (`SetAsideToday`); swiped there to the
/// left it comes back. It lives on Tasks only, as a page under Lists, and opens there by itself on the first launch of the
/// day (`Router.showSpreader`): Back leads to Lists and the pool.
struct MorningReviewPage: View {
    @Environment(Router.self) private var router

    var body: some View {
        MorningReviewList(openSearch: { router.open(.search(.tasks)) }, openNewItem: { router.openNewItem($0) },
                          takesNewItem: { router.path.last == .morningReview }) { router.open(.task($0)) }
    }
}

/// The review's table, its title and its "…"; `openSearch` and `openTask` open their
/// pages where the review's host keeps pages. The table is a list of the list engine (`ReorderableList`): the day's
/// groups as its sections, what was set aside as a last section that stays as it is (`lockedSections`), and a scrolling footer.
struct MorningReviewList: View {
    @Environment(AppModel.self) private var model
    @Environment(Router.self) private var router
    @Environment(\.tokens) var tokens
    @Environment(\.icons) private var icons
    @Environment(\.actions) private var registry
    @Environment(\.openURL) private var openURL
    @Environment(\.chipOrder) private var chipOrder
    @Environment(\.rules) var rules
    @State private var pendingAction: PendingAction?
    /// The task whose exact due date and time is being picked.
    @State private var pickingDue: String?
    @State var dropIn = ListDropIn()
    let openSearch: () -> Void
    /// Opens the new task's page where the review's host keeps pages.
    let openNewItem: (NewItemSeed) -> Void
    /// The review is the page in sight: a dragged "+" is its.
    let takesNewItem: () -> Bool
    let openTask: (String) -> Void

    var body: some View {
        let plan = model.plan(at: model.clock.now)
        let pool = DayPoolRows(plan: plan, daySections: model.sections(on: plan.today),
                               definitions: rules.pool.defaultSections, includesEmpty: true)
        let setAside = setAsideItems(today: plan.today)
        let row = ReviewRow(model: model, tokens: tokens, icons: icons, rules: rules, chipOrder: chipOrder) { pickingDue = $0 }
        ReorderableList(sections: Binding(get: { sections(pool, setAside: setAside) }, set: { pool.move($0, model: model, day: plan.today, savesOrder: true) }), look: "lists",
                        actions: { engine.menu(.context(of: $0.task), for: $0, isToday: true) },
                        traits: traits, swipes: { swipes(for: $0, setAside: setAside) },
                        onNest: { nested($0, $1) }, dropIn: dropIn, onDropIn: { newItemDropped($0, pool: pool, day: plan.today) },
                        features: .all.subtracting([.crossList, .renameSections]), lockedSections: [Self.setAsideSection],
                        onTap: { openTask($0.id) }, footer: footer) { row.content($0) }
            .ignoresSafeArea()
            .engineNewItem(dropIn, owner: Self.newItemOwner, takes: takesNewItem)
            .actionConfirmation($pendingAction) { handler.run($0) }
            .sheet(isPresented: Binding(get: { pickingDue != nil }, set: { if !$0 { pickingDue = nil } })) { dueSheet(today: plan.today) }
            .navigationTitle(Text("review.title"))
            .navigationBarTitleDisplayMode(.inline)
            .searchOnTitleHold(openSearch)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    TimelineView(.everyMinute) { _ in
                        PageMoreMenu(search: openSearch, accessibilityID: "review.more") {
                            Button { Task { await model.resetOrder() } } label: {
                                Label("review.reset", systemImage: icons[.resetSort])
                            }
                            .accessibilityIdentifier("review.reset")
                            Button { Task { await model.simulateDayTurn() } } label: {
                                Label("review.simulateDayTurn", systemImage: icons[.dayBoundary])
                            }
                            .disabled(!model.canSimulateDayTurn)
                            .accessibilityIdentifier("review.simulateDayTurn")
                        }
                    }
                }
            }
    }

    static let setAsideSection = "setAside"

    /// The pool's sections, followed by what was set aside.
    private func sections(_ pool: DayPoolRows, setAside: [DayItem]) -> [ListSection<DayItem>] {
        var sections = pool.sections
        if !setAside.isEmpty {
            sections.append(ListSection(id: Self.setAsideSection,
                                        title: L10n.string("review.group.setAside"), items: setAside))
        }
        return sections
    }

    /// What was taken out of the day (`SetAsideToday`).
    private func setAsideItems(today: LocalDate) -> [DayItem] {
        model.setAsideToday.map { $0.isHabit ? DayItem(habit: $0, on: today) : DayItem(listed: $0) }
    }

    /// A carried row went into a family (today), or out of one to the top level where it was let go.
    private func nested(_ name: String, _ nest: ListNest<String>) {
        Task {
            if let parent = nest.parent {
                await model.nest(name, under: parent, index: nest.index)
            } else {
                await model.unnest(name, order: nest.rows)
            }
        }
    }

    private var traits: ListTraits<DayItem> {
        var traits = ListTraits<DayItem>()
        traits.depth = \.depth
        // A high-priority task's soft red over its row, as in the pool.
        traits.fill = { [tokens] in tokens.plateTint(for: $0.task).map(ThemeColor.init) }
        traits.canNest = { [model] child, parent in model.canNest(child.id, order: [parent.id, child.id]) }
        return traits
    }

    /// To the right Done; to the left Not today or, for a habit, Skip today; set aside, back.
    private func swipes(for item: DayItem, setAside: [DayItem]) -> ListSwipes {
        let isSetAside = setAside.contains { $0.id == item.id }
        return engine.swipes(isSetAside ? .setAside : .review, for: item, isToday: true)
    }

    private var footer: AnyView {
        AnyView(ListGroupFooter(text: Text("review.footer.lines"))
            .padding(.horizontal, ListTheme.app.rows.sideInset)
            .accessibilityIdentifier("review.footer"))
    }

    @ViewBuilder private func dueSheet(today: LocalDate) -> some View {
        if let name = pickingDue, let task = model.task(named: name) {
            let due = task.due ?? TaskDue(day: today, time: rules.editing.defaultTime)
            DuePickerSheet(pick: DuePick(day: due.day, time: due.time), choosesZone: false) { pick in
                Task { await model.setLocalDue(pick?.due, of: name) }
            }
        }
    }
}

extension MorningReviewList {
    /// The pool's actions; opening the task stays where the review is.
    private func perform(_ action: ActionDefinition, on name: String) {
        handler.handle(action, taskName: name)
    }

    private var engine: EngineActions {
        EngineActions(model: model, tokens: tokens, registry: registry, icons: icons) { perform($0, on: $1) }
    }

    private var handler: TaskActionHandler {
        var handler = TaskActionHandler(model: model, router: router, openURL: openURL) { pendingAction = $0 }
        handler.openTask = openTask
        return handler
    }
}
