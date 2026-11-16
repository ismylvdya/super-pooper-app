import SwiftUI

/// One list of the Lists page: the matching tasks by planning level, searchable from the bar's "…" or a hold of its
/// title (`SearchPage`), not by pulling the list down. A row opens the task page
/// (every property can be changed there); "+" on a task of a later level brings it to this week. Rows are dragged within
/// their group like every list. The tab bar's "+" dragged over the list makes a row's room there (over the right part, a
/// subtask's of the row above) and opens the new task's page for that spot; held at the top or bottom edge, it scrolls
/// the list.
struct TaskListScreen: View {
    @Environment(AppModel.self) private var model
    @Environment(Router.self) private var router
    @Environment(\.tokens) private var tokens
    @Environment(\.icons) private var icons
    @Environment(\.openURL) private var openURL
    @Environment(\.rules) private var rules
    @Environment(TaskDragState.self) private var drag: TaskDragState?
    let listID: String
    @State private var pendingAction: PendingAction?
    @State private var frames = ListGroupFrames()
    @State private var rowMids: [String: CGFloat] = [:]
    @State private var rowHeights: [String: CGFloat] = [:]
    @State private var headerMids: [String: CGFloat] = [:]
    /// The rows and headers as they stood when the drag came: the room it makes moves them (`PoolBlock.dragLayout`).
    @State private var dropLayout: PoolDropLayout?
    @State private var screenFrame: CGRect = .zero
    @State private var bottomBar: CGFloat = 0

    var body: some View {
        let list = model.config.lists.list(listID)
        let contents = model.listContents(listID, query: "")
        let shown = Set(contents.groups.flatMap(\.tasks).map(\.name.noteName))
        let groups = drag?.hovering(baseGroups(contents), list: listID, gap: newItemGap) ?? baseGroups(contents)
        List {
            ForEach(groups) { group in
                let level = level(of: group.id, in: contents)
                if contents.namesLevels {
                    ListGroupHeader(title: Text(verbatim: StatusText.title(level))) { headerMids[group.id] = $0 }
                } else {
                    ListGroupGap()
                }
                ForEach(Array(group.items.enumerated()), id: \.element.id) { index, item in
                    if item.id == TaskDragState.newItemGap {
                        gapRow(group: StatusText.title(level), groupID: group.id, id: item.id, index: index, count: group.items.count)
                    } else {
                        row(item.task, parent: ShownParent.parent(of: item.task, shown: shown), depth: item.depth, group: StatusText.title(level),
                            groupID: group.id, index: index, count: group.items.count, rows: group.items)
                    }
                }
                // Dragged like every list.
                .onMove { source, destination in
                    Haptics.play(.reorder)
                    var order = group.items.map(\.id).filter { $0 != TaskDragState.newItemGap }
                    order.move(fromOffsets: source, toOffset: destination)
                    Task { await model.reorderTasks(order) }
                }
            }
            filedGroup(contents.filed)
        }
        .onGeometryChange(for: CGRect.self) { $0.frame(in: .global) } action: { screenFrame = $0 }
        .onGeometryChange(for: CGFloat.self) { $0.safeAreaInsets.bottom } action: { bottomBar = $0 }
        .edgeAutoScroll(drag?.newItemPoint, bottomInset: bottomBar) { delta in
            dropLayout = dropLayout?.shifted(by: -delta)
            newItemMoved(to: drag?.newItemPoint, contents: contents)
        }
        .onChange(of: drag?.newItemPoint) { _, point in newItemMoved(to: point, contents: contents) }
        .onChange(of: drag?.newItemPoint == nil) { _, ended in if ended { dropLayout = nil } }
        .listGroupStyle()
        .listGroupBacking(frames)
        .appList()
        .overlay { if contents.isEmpty { Text("lists.empty").foregroundStyle(tokens.color(.secondaryText)) } }
        .navigationTitle(Text(LocalizedStringKey(list?.title ?? "lists.title")))
        .navigationBarTitleDisplayMode(.inline)
        .searchOnTitleHold { router.open(search) }
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                PageMoreMenu(search: { router.open(search) }, accessibilityID: "list.more")
            }
        }
        .task { await model.openList(listID) }
        .syncsOnPull { await model.openList(listID) }
        .actionConfirmation($pendingAction) { handler.run($0) }
    }

    /// The search of this list: its own tasks.
    private var search: Route { .search(.list(listID)) }

    /// The filed tasks, newest first. Return (the menu, a swipe to the right) brings one back to Soon; the actions go by
    /// the filed task, not its name (a new task may have the same name).
    @ViewBuilder private func filedGroup(_ filed: [TaskItem]) -> some View {
        if !filed.isEmpty {
            ListGroupHeader(title: Text("lists.filed"))
            ForEach(Array(filed.enumerated()), id: \.element.id) { index, task in
                HStack(spacing: tokens.space(.iconTextGap)) {
                    Text(verbatim: task.name).foregroundStyle(tokens.color(.primaryText))
                    Spacer(minLength: 0)
                    if let day = task.completedDate {
                        Text(DateText.format(day, Date.FormatStyle(date: .abbreviated, time: .omitted), calendar: model.calendar))
                            .secondaryText()
                    }
                }
                .listGroupRow(group: "filed", id: task.name, index: index, count: filed.count, frames: frames) {
                    ActionMenuContent(menu: .filedTask, item: DayItem(listed: task), isToday: false) { handler.handle($0, filed: task) }
                }
                .actionSwipes(.task, item: DayItem(listed: task), isToday: false) { handler.handle($0, filed: task) }
            }
        }
    }

    private var handler: TaskActionHandler {
        TaskActionHandler(model: model, router: router, openURL: openURL) { pendingAction = $0 }
    }

    private func row(_ task: TaskItem, parent: String?, depth: Int, group: String, groupID: String, index: Int, count: Int,
                     rows: [DayItem]) -> some View {
        HStack(spacing: tokens.space(.iconTextGap)) {
            // As the pool's row: the name with the chips (no mark before it, no chevron after it); a tap opens the task.
            TaskRowView(item: listed(task, parent: parent), showsDoneState: false) { router.open(.task(task.name)) }
                // A subtask sits under its parent, shifted right, as in the pool.
                .padding(.leading, CGFloat(depth) * tokens.subtaskIndent)
            if task.canPromote {
                Button {
                    Haptics.play(.move)
                    Task { await model.moveToThisWeek(task.name) }
                } label: { Image(systemName: icons[.add]) }
                    .buttonStyle(.borderless)
                    .accessibilityLabel(Text("lists.toThisWeek"))
                    .accessibilityIdentifier("lists.toThisWeek.\(task.name)")
            }
        }
        .modifier(tracking(task.name, groupID: groupID))
        // Reordered like every list, a subtask stays under its parent: it is not dragged on its own.
        .moveDisabled(depth > 0)
        // The pool's menu for the task (Not today has no place outside Today); one tab right or left to the right (D-182),
        // Delete to the left.
        .listGroupRow(group: group, id: task.name, index: index, count: count, frames: frames,
                      tint: tokens.plateTint(for: task)) {
            ActionMenuContent(menu: .context(of: task), item: DayItem(listed: task), isToday: false) {
                handler.handle($0, taskName: task.name)
            }
        }
        .actionSwipes(.listTask, item: DayItem(listed: task), isToday: false) { action in
            if action.id == .indent {
                Task { await model.indent(task.name, rows: rows.filter { $0.id != TaskDragState.newItemGap }) }
            } else {
                handler.handle(action, taskName: task.name)
            }
        }
    }

    /// Where a row stands, for a drag over the list; one scrolled into sight during a drag joins its layout.
    private func tracking(_ id: String, groupID: String) -> RowTracking {
        RowTracking() { frame in
            rowMids[id] = frame.midY
            rowHeights[id] = frame.height
            if id != TaskDragState.newItemGap { dropLayout?.add(row: id, midY: frame.midY, section: groupID, lift: liftByGap(of: id)) }
        }
    }

    /// The task as the pool's row shows it, its parent's name over it where the parent is not in the list.
    private func listed(_ task: TaskItem, parent: String?) -> DayItem {
        var item = DayItem(listed: task)
        item.project = parent
        return item
    }

    // MARK: - Dragging

    /// The list's groups as the pool's sections: a group by its level.
    private func baseGroups(_ contents: TaskListContents) -> [PoolSectionContent] {
        contents.groups.map { group in
            // A subtask stands under its parent, as in the pool.
            PoolSectionContent(id: Self.key(group.status), title: "", isCustom: false,
                               items: SubtaskNesting.nested(group.tasks.map(DayItem.init(listed:))))
        }
    }

    private static func key(_ status: TaskStatus) -> String { String(describing: status) }

    private func level(of key: String, in contents: TaskListContents) -> TaskStatus {
        contents.groups.first { Self.key($0.status) == key }?.status ?? contents.groups.first?.status ?? .thisWeek
    }

    /// The room of the dragged "+" while it is over this list.
    private var newItemGap: DayItem? {
        guard let drag, drag.source == .newItem else { return nil }
        var gap = DayItem(listed: TaskItem(id: .unsaved, name: TaskDragState.newItemGap, status: .thisWeek))
        gap.depth = drag.newItemSpot.depth
        return gap
    }

    /// The rows and headers as they stand now, kept while the drag lasts.
    private func layout(_ contents: TaskListContents) -> PoolDropLayout {
        if let dropLayout { return dropLayout }
        let groups = baseGroups(contents)
        let layout = PoolDropLayout(
            rows: groups.flatMap { group in
                group.items.compactMap { item in rowMids[item.id].map { PoolDropOrder.Row(id: item.id, midY: Double($0), section: group.id) } }
            },
            headers: groups.compactMap { group in headerMids[group.id].map { SectionDropOrder.Header(id: group.id, midY: Double($0)) } },
            all: groups.flatMap { $0.items.map(\.id) }, inSections: true)
        dropLayout = layout
        return layout
    }

    /// How far the room of the "+" pushed `id` down: its height and nothing more (the list's rows touch).
    private func liftByGap(of id: String) -> CGFloat {
        guard let order = drag?.backlogOrder, drag?.backlogTarget == listID, let gap = drag?.draggedID,
              let at = order.firstIndex(of: gap), let spot = order.firstIndex(of: id), spot > at else { return 0 }
        return rowHeights[gap] ?? CGFloat(rules.layoutEstimates.poolRowHeight)
    }

    /// Over the list's right part the row above takes the new task as its subtask.
    private func nesting(order: [String], x: Double, contents: TaskListContents) -> NewItemNesting.Spot {
        guard NewItemNesting.isSubtaskSide(x: x, poolMinX: 0, poolWidth: Double(screenFrame.width), share: rules.gestures.subtaskShare) else {
            return .top
        }
        return NewItemNesting.spot(order: order, gap: TaskDragState.newItemGap, pool: baseGroups(contents).flatMap(\.items), asSubtask: true)
    }

    /// The dragged "+" over the list: rows make room under it, and letting go opens the new task's page for the spot.
    private func newItemMoved(to point: CGPoint?, contents: TaskListContents) {
        let owner = "list.\(listID)"
        guard let drag, drag.source == .newItem, let point, router.path.last == .list(listID), screenFrame.contains(point),
              point.y < screenFrame.maxY - bottomBar else {
            if let drag, drag.backlogTarget == listID {
                withAnimation(tokens.animation) {
                    drag.backlogTarget = nil
                    drag.backlogOrder = nil
                    drag.listSection = nil
                }
            }
            drag?.clearNewItemLanding(owner)
            if drag?.newItemPoint == nil { dropLayout = nil }
            return
        }
        let layout = layout(contents)
        let drop = PoolDropOrder.drop(rows: layout.rows, all: layout.all, headers: layout.headers, inSections: true,
                                      dragged: TaskDragState.newItemGap, at: Double(point.y))
        let section = drop.section ?? layout.rows.first?.section ?? baseGroups(contents).first?.id
        let spot = nesting(order: drop.order, x: Double(point.x - screenFrame.minX), contents: contents)
        if drop.order != drag.backlogOrder || section != drag.listSection || spot != drag.newItemSpot || drag.backlogTarget != listID {
            withAnimation(tokens.animation) {
                drag.backlogTarget = listID
                drag.backlogOrder = drop.order
                drag.listSection = section
                drag.newItemSpot = spot
            }
            Haptics.play(.dragStep)
        }
        let level: TaskStatus = section.map { self.level(of: $0, in: contents) } ?? .thisWeek
        let inGroup = Set(contents.groups.first { $0.status == level }?.tasks.map(\.name) ?? [])
        let groupOrder = drop.order.filter { $0 == TaskDragState.newItemGap || inGroup.contains($0) }
        drag.setNewItemLanding(owner) {
            Haptics.play(.drop)
            let placement: NewItemPlacement = spot.parent.map { .subtask(of: $0, index: spot.index, day: model.context().today) }
                ?? .list(level: TaskStatus.open.contains(level) ? level : .thisWeek, order: groupOrder)
            router.openNewItem(NewItemSeed(kind: .task, placement: placement, estimate: drag.releasedEstimate))
        }
    }

    /// The room of what is dragged, in its group's plate: as tall as a row; as a subtask, the new parent's name in it.
    private func gapRow(group: String, groupID: String, id: String, index: Int, count: Int) -> some View {
        TaggedTaskName(name: " ", parent: drag?.newItemSpot.parent)
            .opacity(drag?.newItemSpot.parent == nil ? 0 : 1)
            .modifier(tracking(id, groupID: groupID))
            .listGroupRow(group: group, id: id, index: index, count: count, frames: frames)
    }
}

/// A row's frame on the screen, told as it changes.
struct RowTracking: ViewModifier {
    let onChange: (CGRect) -> Void

    func body(content: Content) -> some View {
        content.onGeometryChange(for: CGRect.self) { $0.frame(in: .global) } action: { onChange($0) }
    }
}
