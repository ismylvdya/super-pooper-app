import SwiftUI

/// Morning review (the sheet; its list is Soon): the pool as a table — one row per task with property chips edited in place, in
/// Morning, Day and Evening groups; rows reorder by dragging, also into another group (which sets their part
/// of the day). Until the first drag the order follows the automatic sort after every edit; after it the
/// manual order is kept for today. Reset sorting, in the bar's "…", brings the sort back.
/// Tapping a row (outside its chips) opens the task page.
/// A long press opens the same menu as the row in the pool (and moving the finger then drags the row).
/// Swiping a row right is Done; swiping it left has one button: a task's Not today, a habit's Skip today. What was taken
/// out of today waits in the Not today group at the bottom (`SetAsideToday`); swiped there to the right it comes back.
/// The sheet: opened by itself in the morning (or from Today); a task opens on a page pushed in the sheet.
struct MorningReviewScreen: View {
    @State private var path: [Route] = []

    var body: some View {
        NavigationStack(path: $path) {
            MorningReviewList(openSearch: { path.append(.search(.tasks)) }) { path.append(.task($0)) }
                .navigationDestination(for: Route.self) { route in
                    switch route {
                    case .task(let name): TaskPageScreen(taskName: name)
                    case .search(let scope): SearchPage(scope: scope)
                    default: EmptyView()
                    }
                }
        }
        // Over the sheet's bar, on every page pushed in it.
        .bannerHost()
    }
}

/// The page of the Lists page: the same review, with Back and Search; a task opens on the tab's own stack.
struct MorningReviewPage: View {
    @Environment(Router.self) private var router

    var body: some View {
        MorningReviewList(openSearch: { router.open(.search(.tasks)) }) { router.open(.task($0)) }
    }
}

/// The review's table, its title and its "…" (Search, Reset sorting, Undo, Redo); `openSearch` and `openTask` open their
/// pages where the review's host keeps pages.
struct MorningReviewList: View {
    @Environment(AppModel.self) private var model
    @Environment(Router.self) private var router
    @Environment(\.tokens) private var tokens
    @Environment(\.icons) private var icons
    @Environment(\.openURL) private var openURL
    @State private var pendingAction: PendingAction?
    @State private var frames = ListGroupFrames()
    let openSearch: () -> Void
    let openTask: (String) -> Void

    var body: some View {
        let plan = model.plan(at: model.clock.now)
        List {
            Group {
                let rows = ReviewGroups.rows(plan.pool)
                let items = Dictionary(plan.pool.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
                let guides = ReviewGroups.guides(rows, items: items)
                ForEach(Array(rows.enumerated()), id: \.element) { index, row in
                    switch row {
                    case .header(let group):
                        ListGroupHeader(title: Text(LocalizedStringKey("review.group." + group.rawValue)))
                            .moveDisabled(true)
                            .accessibilityIdentifier("review.group.\(group.rawValue)")
                    case .item(let name):
                        if let item = items[name] {
                            let position = ReviewGroups.position(of: index, in: rows)
                            ReviewRow(item: item, today: plan.today) { openTask(item.id) }
                                // A subtask sits under its parent, shifted right, as in the pool.
                                .padding(.leading, CGFloat(item.depth) * tokens.subtaskIndent)
                                .background(alignment: .topLeading) {
                                    if let guide = guides[name] {
                                        SubtaskGuideLines(guide: guide, turnY: tokens.space(.reviewRowVertical) + tokens.uiFont(.taskTitle).lineHeight / 2,
                                                          gap: 0)
                                    }
                                }
                                // The row keeps its top and bottom inset inside, where a tap opens the task.
                                .listGroupRow(group: ReviewGroups.group(of: index, in: rows)?.rawValue ?? "", id: name,
                                              index: position.index, count: position.count, frames: frames, vertical: 0,
                                              separatorIndent: CGFloat(item.depth) * tokens.subtaskIndent) {
                                    ActionMenuContent(menu: .context(of: item.task), item: item) {
                                        perform($0, on: item.id)
                                    }
                                }
                                .accessibilityIdentifier("review:\(item.id)")
                                // Done to the right; to the left Not today or, for a habit, Skip today.
                                .actionSwipes(.review, item: item) { perform($0, on: item.id) }
                        }
                    }
                }
                .onMove { source, destination in
                    Haptics.play(.reorder)
                    model.applyReviewMove(ReviewGroups.move(rows, from: source, to: destination, pool: plan.pool))
                }
            }
            setAside(today: plan.today)
            ListGroupFooter(text: Text(model.dayState.manualOrder == nil ? "review.footer.auto" : "review.footer.manual"))
                .accessibilityIdentifier("review.footer")
        }
        .listGroupStyle()
        .listGroupBacking(frames)
        .appList()
        // The first group starts closer to the bar than a list's own top gap.
        .contentMargins(.top, tokens.space(.reviewTop), for: .scrollContent)
        .actionConfirmation($pendingAction) { handler.run($0) }
        .navigationTitle(Text("review.title"))
        .navigationBarTitleDisplayMode(.inline)
        .searchOnTitleHold(openSearch)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                PageMoreMenu(search: openSearch, accessibilityID: "review.more") {
                    Button { model.resetOrder() } label: { Label("review.reset", systemImage: icons[.resetSort]) }
                        .disabled(model.dayState.manualOrder == nil)
                        .accessibilityIdentifier("review.reset")
                }
            }
        }
    }

    /// What was taken out of today, at the bottom: swiped to the right it comes back (`SetAsideToday`).
    @ViewBuilder private func setAside(today: LocalDate) -> some View {
        let notes = model.setAsideToday
        if !notes.isEmpty {
            ListGroupHeader(title: Text("review.group.setAside"))
                .moveDisabled(true)
                .accessibilityIdentifier("review.group.setAside")
            ForEach(Array(notes.enumerated()), id: \.element.name) { index, note in
                let item = note.isHabit ? DayItem(habit: note, on: today) : DayItem(listed: note)
                ReviewRow(item: item, today: today) { openTask(note.name) }
                    .listGroupRow(group: "setAside", id: note.name, index: index, count: notes.count, frames: frames, vertical: 0) {
                        ActionMenuContent(menu: .context(of: note), item: item) { perform($0, on: note.name) }
                    }
                    .moveDisabled(true)
                    .accessibilityIdentifier("review.setAside:\(note.name)")
                    .actionSwipes(.setAside, item: item) { perform($0, on: note.name) }
            }
        }
    }
}

extension MorningReviewList {
    /// The pool's actions; opening the task stays where the review is.
    private func perform(_ action: ActionDefinition, on name: String) {
        handler.handle(action, taskName: name)
    }

    private var handler: TaskActionHandler {
        var handler = TaskActionHandler(model: model, router: router, openURL: openURL) { pendingAction = $0 }
        handler.openTask = openTask
        return handler
    }
}
