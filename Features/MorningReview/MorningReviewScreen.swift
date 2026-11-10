import SwiftUI

/// Morning review (the sheet; its list is Soon): the pool as a table — one row per task with property chips edited in place, in
/// Morning, Day and Evening groups; rows reorder by dragging, also into another group (which sets their part
/// of the day). Until the first drag the order follows the automatic sort after every edit; after it the
/// manual order is kept for today. Reset sorting brings the sort back.
/// Tapping a row (outside its chips) opens the task page.
/// A long press opens the same menu as the row in the pool (and moving the finger then drags the row).
/// Swiping a row right is Done; swiping it left has one button: a task's Not today (it stays this week and waits in "Not
/// Today" at the bottom, and in tomorrow's review; swiping it there to the right brings it back), a habit's Skip today.
/// The sheet: opened by itself in the morning (or from Today); a task opens on a page pushed in the sheet.
struct MorningReviewScreen: View {
    @State private var path: [Route] = []

    var body: some View {
        NavigationStack(path: $path) {
            MorningReviewList { path.append(.task($0)) }
                .navigationDestination(for: Route.self) { route in
                    switch route {
                    case .task(let name): TaskPageScreen(taskName: name)
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
    @Environment(\.tokens) private var tokens

    var body: some View {
        MorningReviewList(resetPlacement: .topBarTrailing) { router.open(.task($0)) }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { router.open(.search(.tasks)) } label: { SearchGlyph() }
                        .tint(tokens.color(.accent))
                        .accessibilityLabel(Text("search.title"))
                        .accessibilityIdentifier("review.search")
                }
            }
    }
}

/// The review's table, its title and its Reset sorting button; `openTask` opens a task where its host keeps pages.
struct MorningReviewList: View {
    @Environment(AppModel.self) private var model
    @Environment(Router.self) private var router
    @Environment(\.tokens) private var tokens
    @Environment(\.icons) private var icons
    @Environment(\.openURL) private var openURL
    @State private var pendingAction: PendingAction?
    @State private var frames = ListGroupFrames()
    /// The sheet keeps Reset sorting on the left; a page has Back there.
    var resetPlacement: ToolbarItemPlacement = .topBarLeading
    let openTask: (String) -> Void

    var body: some View {
        let plan = model.plan(at: model.clock.now)
        List {
            Group {
                let rows = ReviewGroups.rows(plan.pool)
                let items = Dictionary(plan.pool.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
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
        .toolbar {
            ToolbarItem(placement: resetPlacement) {
                Button { model.resetOrder() } label: { Image(systemName: icons[.resetSort]) }
                .accessibilityLabel(Text("review.reset"))
                .disabled(model.dayState.manualOrder == nil)
            }
        }
    }
}

extension MorningReviewList {
    /// The pool's actions; opening the task stays where the review is.
    private func perform(_ action: ActionDefinition, on name: String) {
        if action.id == .open {
            openTask(name)
        } else {
            handler.handle(action, taskName: name)
        }
    }

    private var handler: TaskActionHandler {
        TaskActionHandler(model: model, router: router, openURL: openURL) { pendingAction = $0 }
    }
}
