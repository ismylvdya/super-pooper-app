import SwiftUI

/// Morning review (the sheet; its list is Soon): the pool as a table — one row per task with property chips edited in place, in
/// Morning, Day and Evening groups; rows reorder by dragging, also into another group (which sets their part
/// of the day). Until the first drag the order follows the automatic sort after every edit; after it the
/// manual order is kept for today. Reset sorting, in the bar's "…", brings the sort back.
/// Tapping a row (outside its chips) opens the task page.
/// A long press opens the same menu as the row in the pool (and moving the finger then drags the row).
/// Swiping a row right is Done; swiping it left has one button: a task's Not today, a habit's Skip today. What was taken
/// out of today waits in the Not today group at the bottom (`SetAsideToday`); swiped there to the left it comes back.
/// The sheet: opened by itself in the morning (or from Today); a task opens on a page pushed in the sheet.
/// Its Tomorrow (the switch at the top) plans the next day the evening before: what tomorrow's turn will bring, kept out
/// of it with Not tomorrow, in an order of its own; reviewed so, it does not open by itself that morning.
struct MorningReviewScreen: View {
    @Environment(\.tokens) private var tokens
    @State private var path: [Route] = []

    var body: some View {
        NavigationStack(path: $path) {
            MorningReviewList(openSearch: { path.append(.search(.tasks)) }, openNewItem: { path.append(.newItem($0)) },
                              takesNewItem: { path.isEmpty }, bubbleRoom: tokens.bar(.newItemBubble) + tokens.bar(.newItemBubbleInset)) {
                path.append(.task($0))
            }
                .navigationDestination(for: Route.self) { route in
                    switch route {
                    case .task(let name): TaskPageScreen(taskName: name)
                    case .search(let scope): SearchPage(scope: scope)
                    case .newItem(let seed): NewItemScreen(seed: seed)
                    default: EmptyView()
                    }
                }
        }
        // The tab bar's "+" is under the sheet: the review has its own, tapped or dragged into it.
        .overlay(alignment: .bottomTrailing) {
            if path.isEmpty { FloatingNewItemButton { path.append(.newItem(.opening(on: .today))) } }
        }
        .overlay { NewItemDragOverlay() }
        // Over the sheet's bar, on every page pushed in it.
        .bannerHost()
    }
}

/// The page of the Lists page: the same review, with Back and Search; a task opens on the tab's own stack.
struct MorningReviewPage: View {
    @Environment(Router.self) private var router

    var body: some View {
        MorningReviewList(openSearch: { router.open(.search(.tasks)) }, openNewItem: { router.openNewItem($0) },
                          takesNewItem: { router.path.last == .morningReview }, bubbleRoom: 0) { router.open(.task($0)) }
    }
}

/// The review's table, its title and its "…" (Search, Reset sorting, Undo, Redo); `openSearch` and `openTask` open their
/// pages where the review's host keeps pages.
struct MorningReviewList: View {
    @Environment(AppModel.self) private var model
    @Environment(Router.self) private var router
    @Environment(\.tokens) var tokens
    @Environment(\.icons) private var icons
    @Environment(\.openURL) private var openURL
    @State private var pendingAction: PendingAction?
    @State private var frames = ListGroupFrames()
    /// Today's review, or tomorrow's planned today.
    @State private var isTomorrow = false
    @Environment(\.rules) var rules
    @Environment(TaskDragState.self) var drag: TaskDragState?
    /// Where the rows and headers stand on the screen, for a dragged "+".
    @State var rowMids: [String: CGFloat] = [:]
    @State var rowHeights: [String: CGFloat] = [:]
    @State var headerMids: [String: CGFloat] = [:]
    @State var dropLayout: PoolDropLayout?
    @State var screenFrame: CGRect = .zero
    @State var bottomBar: CGFloat = 0
    let openSearch: () -> Void
    /// Opens the new task's page where the review's host keeps pages.
    let openNewItem: (NewItemSeed) -> Void
    /// The review is the page in sight: a dragged "+" is its.
    let takesNewItem: () -> Bool
    /// Room at the bottom the review's own "+" takes: the list does not scroll by itself under it.
    let bubbleRoom: CGFloat
    let openTask: (String) -> Void

    var body: some View {
        let plan = isTomorrow ? model.tomorrowPlan() : model.plan(at: model.clock.now)
        List {
            // Only in the evening: planning tomorrow is a thing of the day's end (`DayRules.tomorrowReviewFrom`). It
            // scrolls with the rows, not with the bar.
            if model.offersTomorrowReview {
                Picker(selection: $isTomorrow) {
                    Text("review.mode.today").tag(false)
                    Text("review.mode.tomorrow").tag(true)
                } label: { EmptyView() }
                    .pickerStyle(.segmented)
                    .accessibilityIdentifier("review.mode")
                    .listGroupSpacer()
                    .moveDisabled(true)
            }
            Group {
                let rows = shownRows(plan)
                let items = Dictionary(plan.pool.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
                let guides = ReviewGroups.guides(rows, items: items)
                ForEach(Array(rows.enumerated()), id: \.element) { index, row in
                    switch row {
                    case .header(let group):
                        ListGroupHeader(title: Text(LocalizedStringKey("review.group." + group.rawValue))) { headerMids[group.rawValue] = $0 }
                            .moveDisabled(true)
                            .accessibilityIdentifier("review.group.\(group.rawValue)")
                    case .item(let name) where name == TaskDragState.newItemGap:
                        let position = ReviewGroups.position(of: index, in: rows)
                        TaggedTaskName(name: " ", parent: drag?.newItemSpot.parent)
                            .opacity(drag?.newItemSpot.parent == nil ? 0 : 1)
                            .modifier(RowTracking { frame in rowHeights[name] = frame.height })
                            .listGroupRow(group: ReviewGroups.group(of: index, in: rows)?.rawValue ?? "", id: name,
                                          index: position.index, count: position.count, frames: frames)
                            .moveDisabled(true)
                    case .item(let name):
                        if let item = items[name] {
                            let position = ReviewGroups.position(of: index, in: rows)
                            ReviewRow(item: item, today: plan.today) { openTask(item.id) }
                                // A subtask sits under its parent, shifted right, as in the pool.
                                .padding(.leading, CGFloat(item.depth) * tokens.listSubtaskIndent)
                                .modifier(RowTracking { frame in
                                    rowMids[name] = frame.midY
                                    rowHeights[name] = frame.height
                                    let group = ReviewGroups.Group(item.task.habit.timeOfDay).rawValue
                                    dropLayout?.add(row: name, midY: frame.midY, section: group, lift: liftByGap(of: name))
                                })
                                .background(alignment: .topLeading) {
                                    if let guide = guides[name] {
                                        SubtaskGuideLines(guide: guide, turnY: tokens.space(.reviewRowVertical) + tokens.uiFont(.taskTitle).lineHeight / 2,
                                                          gap: 0, inList: true)
                                    }
                                }
                                // The row keeps its top and bottom inset inside, where a tap opens the task.
                                // A high-priority task's soft red over its row, as in the pool.
                                .listGroupRow(group: ReviewGroups.group(of: index, in: rows)?.rawValue ?? "", id: name,
                                              index: position.index, count: position.count, frames: frames, vertical: 0,
                                              separatorIndent: CGFloat(item.depth) * tokens.listSubtaskIndent,
                                              tint: tokens.plateTint(for: item.task)) {
                                    ActionMenuContent(menu: .context(of: item.task), item: item, isToday: !isTomorrow) {
                                        perform($0, on: item.id)
                                    }
                                }
                                .accessibilityIdentifier("review:\(item.id)")
                                // To the right one tab right or left (D-182); to the left Not today or, for a habit, Skip today.
                                .actionSwipes(isTomorrow ? .reviewTomorrow : .review, item: item) { action in
                                    if action.id == .indent {
                                        // The rows of its own group: a group's first row has nothing above it.
                                        let group = ReviewGroups.group(of: index, in: rows)
                                        let shown = rows.indices.compactMap { at -> DayItem? in
                                            guard case .item(let name) = rows[at], ReviewGroups.group(of: at, in: rows) == group else { return nil }
                                            return items[name]
                                        }
                                        Task { await model.indent(item.id, rows: shown) }
                                    } else {
                                        perform(action, on: item.id)
                                    }
                                }
                        }
                    }
                }
                .onMove { source, destination in
                    Haptics.play(.reorder)
                    let move = ReviewGroups.move(rows, from: source, to: destination, pool: plan.pool)
                    Task { await model.applyReviewMove(move) }
                }
            }
            setAside(today: plan.today)
            ListGroupFooter(text: Text("review.footer.lines"))
                .accessibilityIdentifier("review.footer")
        }
        .listGroupStyle()
        .listGroupBacking(frames)
        .appList()
        // The first group starts closer to the bar than a list's own top gap.
        .contentMargins(.top, tokens.space(.reviewTop), for: .scrollContent)
        .onChange(of: model.offersTomorrowReview) { _, offered in if !offered { isTomorrow = false } }
        .onChange(of: isTomorrow) { _, tomorrow in if tomorrow { model.markTomorrowReviewed() } }
        .onGeometryChange(for: CGRect.self) { $0.frame(in: .global) } action: { screenFrame = $0 }
        .onGeometryChange(for: CGFloat.self) { $0.safeAreaInsets.bottom } action: { bottomBar = $0 }
        .edgeAutoScroll(drag?.newItemPoint, bottomInset: bottomBar + bubbleRoom) { delta in
            dropLayout = dropLayout?.shifted(by: -delta)
            newItemMoved(to: drag?.newItemPoint, plan: plan)
        }
        .onChange(of: drag?.newItemPoint) { _, point in newItemMoved(to: point, plan: plan) }
        .onChange(of: drag?.newItemPoint == nil) { _, ended in if ended { dropLayout = nil } }
        .actionConfirmation($pendingAction) { handler.run($0) }
        .navigationTitle(Text("review.title"))
        .navigationBarTitleDisplayMode(.inline)
        .searchOnTitleHold(openSearch)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                PageMoreMenu(search: openSearch, accessibilityID: "review.more") {
                    Button { Task { await model.resetOrder(tomorrow: isTomorrow) } } label: {
                        Label("review.reset", systemImage: icons[.resetSort])
                    }
                        .accessibilityIdentifier("review.reset")
                }
            }
        }
    }

    /// What was taken out of the day, at the bottom: swiped to the left it comes back (`SetAsideToday`; on Tomorrow, what is
    /// kept out of tomorrow).
    @ViewBuilder private func setAside(today: LocalDate) -> some View {
        let notes = isTomorrow ? model.setAsideTomorrow : model.setAsideToday
        if !notes.isEmpty {
            // Set well apart from the day's groups: a divider with wide room above and below it.
            Rectangle()
                .fill(tokens.color(.listSeparator))
                .frame(height: tokens.size(.subtaskLine))
                .padding(.vertical, tokens.space(.reviewSetAsideGap))
                .listGroupSpacer()
                .moveDisabled(true)
                .accessibilityHidden(true)
            ListGroupHeader(title: Text(isTomorrow ? "review.group.setAsideTomorrow" : "review.group.setAside"))
                .moveDisabled(true)
                .accessibilityIdentifier("review.group.setAside")
            ForEach(Array(notes.enumerated()), id: \.element.name) { index, note in
                let item = note.isHabit ? DayItem(habit: note, on: today) : DayItem(listed: note)
                ReviewRow(item: item, today: today) { openTask(note.name) }
                    .listGroupRow(group: "setAside", id: note.name, index: index, count: notes.count, frames: frames, vertical: 0) {
                        ActionMenuContent(menu: .context(of: note), item: item, isToday: !isTomorrow) { perform($0, on: note.name) }
                    }
                    .moveDisabled(true)
                    .accessibilityIdentifier("review.setAside:\(note.name)")
                    .actionSwipes(isTomorrow ? .setAsideTomorrow : .setAside, item: item) { perform($0, on: note.name) }
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
