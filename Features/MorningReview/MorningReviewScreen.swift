import SwiftUI

/// Soon (the review): the pool as a table — one row per task with property chips edited in place, in
/// Morning, Day and Evening groups; rows reorder by dragging, also into another group (which sets their part
/// of the day). Until the first drag the order follows the automatic sort after every edit; after it the
/// manual order is kept for today. Reset sorting brings the sort back.
/// Tapping a row (outside its chips) opens the task page; "+" creates a new this-week task.
/// A long press opens the same menu as the row in the pool (and moving the finger then drags the row).
/// Swiping a row right is Done; swiping a task left is the menu's Not today (then Delete): it stays this week and waits
/// in "Not Today" at the bottom (and in tomorrow's review); swiping it there to the right brings it back.
struct MorningReviewScreen: View {
    @Environment(AppModel.self) private var model
    @Environment(Router.self) private var router
    @Environment(\.tokens) private var tokens
    @Environment(\.icons) private var icons
    @Environment(\.openURL) private var openURL
    @State private var path: [Route] = []
    @State private var pendingAction: PendingAction?
    @State private var frames = ListGroupFrames()

    var body: some View {
        NavigationStack(path: $path) {
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
                                ReviewRow(item: item, today: plan.today) { path.append(.task(item.id)) }
                                    // A subtask sits under its parent, shifted right, as in the pool.
                                    .padding(.leading, CGFloat(item.depth) * tokens.space(.subtaskIndent))
                                    // The row keeps its top and bottom inset inside, where a tap opens the task.
                                    .listGroupRow(group: ReviewGroups.group(of: index, in: rows)?.rawValue ?? "", id: name,
                                                  index: position.index, count: position.count, frames: frames, vertical: 0,
                                                  separatorIndent: CGFloat(item.depth) * tokens.space(.subtaskIndent)) {
                                        ActionMenuContent(menu: .context(of: item.task), item: item) {
                                            perform($0, on: item.id)
                                        }
                                    }
                                    .accessibilityIdentifier("review:\(item.id)")
                                    // Done to the right; to the left the pool menu's Not today (a full swipe), then Delete.
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
                let postponed = model.postponedTasks
                if !postponed.isEmpty {
                    Group {
                        ListGroupHeader(title: Text("review.postponed"))
                        ForEach(Array(postponed.enumerated()), id: \.element.name) { index, task in
                            ReviewRow(item: DayItem(listed: task), today: plan.today) {
                                path.append(.task(task.name))
                            }
                            .listGroupRow(group: "postponed", id: task.name, index: index, count: postponed.count,
                                          frames: frames, vertical: 0)
                            .accessibilityIdentifier("review.notToday:\(task.name)")
                            .opacity(tokens.opacity(.blocked))
                            // Back to today to the right, Delete to the left.
                            .actionSwipes(.postponed, item: DayItem(listed: task)) { perform($0, on: task.name) }
                        }
                        ListGroupFooter(text: Text("review.postponed.hint"))
                    }
                }
            }
            .listGroupStyle()
            .listGroupBacking(frames)
            .appList()
            // The first group starts closer to the bar than a list's own top gap.
            .contentMargins(.top, tokens.space(.reviewTop), for: .scrollContent)
            .bannerHost()
            .actionConfirmation($pendingAction) { handler.run($0) }
            .navigationDestination(for: Route.self) { route in
                switch route {
                case .task(let name): TaskPageScreen(taskName: name).bannerHost()
                case .newTask: NewNoteScreen(kind: .task).bannerHost()
                default: EmptyView()
                }
            }
            .navigationTitle(Text("review.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { model.resetOrder() } label: { Image(systemName: icons[.resetSort]) }
                    .accessibilityLabel(Text("review.reset"))
                    .disabled(model.dayState.manualOrder == nil)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button { path.append(.newTask) } label: {
                        Image(systemName: icons[.newTask])
                    }
                    .accessibilityLabel(Text("task.new.add"))
                    .accessibilityIdentifier("task.new")
                }
            }
        }
    }
}

extension MorningReviewScreen {
    /// The pool's actions; opening the task stays in this sheet.
    private func perform(_ action: ActionDefinition, on name: String) {
        if action.id == .open {
            path.append(.task(name))
        } else {
            handler.handle(action, taskName: name)
        }
    }

    private var handler: TaskActionHandler {
        TaskActionHandler(model: model, router: router, openURL: openURL) { pendingAction = $0 }
    }
}
