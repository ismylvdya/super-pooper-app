import SwiftUI

/// A backlog page left of the pool (Soon, Half year, Someday): the list's tasks for the day shown, on the pool's plates,
/// with the pool's tap and long-press menu; each can be dragged to another page, into the pool or onto the timeline.
/// A task dragged here takes the list's level, and the rows part where the list will hold it; a row dragged off the page
/// closes up, as in the pool. The tab bar's "+" dragged over the page makes a row's room there (over the right part, a
/// subtask's of the row above); let go, it opens the new task's page for that spot of the list. Held at the page's top or
/// bottom edge, it scrolls the list.
struct BacklogPage: View {
    @Environment(AppModel.self) private var model
    @Environment(Router.self) private var router
    @Environment(\.rules) private var rules
    @Environment(\.tokens) private var tokens
    @Environment(TaskDragState.self) private var drag: TaskDragState?
    let list: BacklogList
    let plan: DayPlan
    let handler: TaskActionHandler
    /// Space under the page that belongs to the home indicator (the list scrolls under it).
    let bottomInset: CGFloat
    /// The edges of the list that lie under a system bar (`edgeFades`).
    let barEdges: Edge.Set
    /// The screen's margins beside the page take a drop too: a drag that turned to the page from the edge of the screen
    /// is let go there.
    let edgeInset: CGFloat
    /// Where the rows stand, for a task dragged within the page.
    @State private var rowMids: [String: CGFloat] = [:]
    @State private var rowHeights: [String: CGFloat] = [:]
    /// The rows as they stood when the "+" came over the page: the room it makes moves them (`PoolBlock.dragLayout`).
    @State private var newItemLayout: [PoolDropOrder.Row]?
    /// The page on the screen, where the dragged "+" is compared with it.
    @State private var screenFrame: CGRect = .zero
    private static let dropSpace = "backlogDrop"

    var body: some View {
        let items = rows
        ScrollView {
            LazyVStack(alignment: .leading, spacing: tokens.space(.poolRowGap)) {
                ForEach(items) { item in
                    Group {
                        if item.id == TaskDragState.newItemGap
                            || (drag?.isBacklogLanding(item.id, on: list.id) == true && drag?.newItemSpot.parent != nil) {
                            NewItemGapPlate(depth: item.depth, extraLines: drag?.newItemEstimate.map(rules.pool.extraLines(forEstimate:)) ?? 0)
                        } else {
                            PoolRow(item: item, isToday: false, isCompact: true, handler: handler, dragSource: .backlog(list.id))
                                .dropGap(drag?.isBacklogLanding(item.id, on: list.id) == true)
                                .closedUp(drag?.isBacklogGap(item.id, on: list.id) == true, gap: tokens.space(.poolRowGap))
                        }
                    }
                    .onGeometryChange(for: CGRect.self) { $0.frame(in: .named(Self.dropSpace)) } action: { frame in
                        rowMids[item.id] = frame.midY
                        rowHeights[item.id] = frame.height
                        if item.id != TaskDragState.newItemGap, newItemLayout?.contains(where: { $0.id == item.id }) == false {
                            newItemLayout?.append(PoolDropOrder.Row(id: item.id, midY: Double(frame.midY - liftByGap(of: item.id))))
                        }
                    }
                }
            }
        }
        // The dragged "+" at the top or bottom edge scrolls the rows; the room it makes follows.
        .edgeAutoScroll(drag?.source == .newItem ? drag?.newItemPoint : nil, bottomInset: bottomInset) { delta in
            newItemLayout = newItemLayout?.map { PoolDropOrder.Row(id: $0.id, midY: $0.midY - Double(delta)) }
            newItemMoved(to: drag?.newItemPoint)
        }
        .contentMargins(.bottom, bottomInset + tokens.space(.scrollEndRoom), for: .scrollContent)
        .scrollBounceBehavior(.always)
        .scrollIndicators(.hidden)
        .syncsOnPull()
        .edgeFades(bottomExtension: bottomInset, barEdges: barEdges)
        .liftRoom()
        .overlay(alignment: .top) {
            if items.isEmpty {
                Text("lists.empty")
                    .secondaryText(.hint)
                    .frame(maxWidth: .infinity, minHeight: tokens.size(.poolCounter))
            }
        }
        .coordinateSpace(.named(Self.dropSpace))
        .onGeometryChange(for: CGRect.self) { $0.frame(in: .global) } action: { screenFrame = $0 }
        .onChange(of: drag?.newItemPoint) { _, point in newItemMoved(to: point) }
        .contentShape(Rectangle())
        .modifier(dropTarget)
        .background {
            Color.clear
                .contentShape(Rectangle())
                .modifier(dropTarget)
                .padding(.horizontal, -edgeInset)
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("backlog.\(list.id)")
    }

    private var dropTarget: BacklogDropTarget {
        BacklogDropTarget(drag: drag, list: list.id, animation: tokens.animation, canDrop: { model.canBringFromBacklog($0.id) },
                          onDrop: dropped, onRefused: { model.refuseDrop($0.id, onto: .list(list.title)) },
                          rows: { rows.compactMap { item in rowMids[item.id].map { PoolDropOrder.Row(id: item.id, midY: Double($0)) } } },
                          onReorder: { order in
                              Haptics.play(.drop)
                              Task { await model.reorderTasks(order) }
                          },
                          nesting: { order, dragged, x in
                              guard NewItemNesting.isSubtaskSide(x: x, poolMinX: 0, poolWidth: Double(screenFrame.width), share: rules.gestures.subtaskShare),
                                    model.canNest(dragged, order: order) else { return .top }
                              return NewItemNesting.spot(order: order, gap: dragged, pool: model.backlogTasks(list, plan: plan).map(DayItem.init(listed:)),
                                                         asSubtask: true)
                          },
                          onNest: { item, spot in
                              guard let parent = spot.parent else { return }
                              Haptics.play(.drop)
                              Task { await model.nest(item.id, under: parent, index: spot.index) }
                          })
    }

    /// The list's tasks; while a task from elsewhere is over the page, it too, at the end of the list; while the "+" is
    /// over it, its room at the spot under the finger.
    private var rows: [DayItem] {
        let tasks = model.backlogTasks(list, plan: plan)
        var items = tasks.map(DayItem.init(listed:))
        if let gap = newItemGap { items.append(gap) }
        if let order = drag?.backlogOrder {
            let place = Dictionary(order.enumerated().map { ($1, $0) }, uniquingKeysWith: { first, _ in first })
            items.sort { (place[$0.id] ?? .max) < (place[$1.id] ?? .max) }
        }
        // A row of the page over its right part stands as the subtask of the row above it.
        if let drag, drag.source == .backlog(list.id), drag.newItemSpot.parent != nil, let dragged = drag.item?.id,
           let at = items.firstIndex(where: { $0.id == dragged }) {
            items[at].depth = drag.newItemSpot.depth
        }
        if let dragged = drag?.item, drag?.isBacklogLanding(dragged.id, on: list.id) == true,
           !tasks.contains(where: { $0.name.isSameNoteName(as: dragged.id) }) {
            items.append(DayItem(listed: dragged.task))
        }
        return items
    }

    /// The room of the dragged "+" while it is over this page.
    private var newItemGap: DayItem? {
        guard let drag, drag.source == .newItem, drag.backlogTarget == list.id else { return nil }
        var gap = DayItem(listed: TaskItem(id: .unsaved, name: TaskDragState.newItemGap, status: list.status))
        gap.depth = drag.newItemSpot.depth
        return gap
    }

    /// How far the room of the "+" pushed `id` down: its height and a gap, for what stands after it.
    private func liftByGap(of id: String) -> CGFloat {
        guard let order = drag?.backlogOrder, let at = order.firstIndex(of: TaskDragState.newItemGap),
              let spot = order.firstIndex(of: id), spot > at else { return 0 }
        return (rowHeights[TaskDragState.newItemGap] ?? CGFloat(rules.layoutEstimates.poolRowHeight)) + tokens.space(.poolRowGap)
    }

    /// The dragged "+" over the page: rows make room under it, and letting go opens the new task's page for the spot.
    private func newItemMoved(to point: CGPoint?) {
        let owner = "backlog.\(list.id)"
        guard let drag, drag.source == .newItem, let point, router.takesNewItemOnTasks, screenFrame.contains(point) else {
            newItemLayout = nil
            if let drag, drag.backlogTarget == list.id, drag.source == .newItem {
                withAnimation(tokens.animation) {
                    drag.backlogTarget = nil
                    drag.backlogOrder = nil
                }
            }
            drag?.clearNewItemLanding(owner)
            return
        }
        let tasks = model.backlogTasks(list, plan: plan).map(DayItem.init(listed:))
        let layout = newItemLayout ?? tasks.compactMap { item in rowMids[item.id].map { PoolDropOrder.Row(id: item.id, midY: Double($0)) } }
        newItemLayout = layout
        let order = PoolDropOrder.drop(rows: layout, all: tasks.map(\.id), headers: [], dragged: TaskDragState.newItemGap,
                                       at: Double(point.y - screenFrame.minY)).order
        let asSubtask = NewItemNesting.isSubtaskSide(x: Double(point.x), poolMinX: Double(screenFrame.minX), poolWidth: Double(screenFrame.width),
                                                     share: rules.gestures.subtaskShare)
        let nesting = NewItemNesting.spot(order: order, gap: TaskDragState.newItemGap, pool: tasks, asSubtask: asSubtask)
        let changed = order != drag.backlogOrder || nesting != drag.newItemSpot || drag.backlogTarget != list.id
        if changed {
            withAnimation(tokens.animation) {
                drag.backlogTarget = list.id
                drag.backlogOrder = order
                drag.newItemSpot = nesting
            }
            Haptics.play(.dragStep)
        }
        drag.setNewItemLanding(owner) {
            Haptics.play(.drop)
            let placement: NewItemPlacement = nesting.parent.map { .subtask(of: $0, index: nesting.index, day: plan.today) }
                ?? .list(level: list.status, order: order)
            router.openNewItem(NewItemSeed(kind: .task, placement: placement, estimate: drag.releasedEstimate))
        }
    }

    private func dropped(_ item: DayItem, from source: TaskDragState.Source) {
        Haptics.play(.drop)
        Task {
            await model.moveToBacklog(item.id, list: list, shown: plan.today, fromShownDay: !source.isBacklog)
        }
    }
}

private struct BacklogDropTarget: ViewModifier {
    let drag: TaskDragState?
    let list: String
    let animation: Animation
    let canDrop: (DayItem) -> Bool
    let onDrop: (DayItem, TaskDragState.Source) -> Void
    let onRefused: (DayItem) -> Void
    let rows: () -> [PoolDropOrder.Row]
    let onReorder: ([String]) -> Void
    var nesting: (_ order: [String], _ dragged: String, _ x: Double) -> NewItemNesting.Spot = { _, _, _ in .top }
    var onNest: (DayItem, NewItemNesting.Spot) -> Void = { _, _ in }

    func body(content: Content) -> some View {
        if let drag {
            content.onDrop(of: TaskDragState.types, delegate: BacklogDropDelegate(drag: drag, list: list, animation: animation,
                                                                                canDrop: canDrop, onDrop: onDrop, onRefused: onRefused,
                                                                                rows: rows, onReorder: onReorder,
                                                                                nesting: nesting, onNest: onNest))
        } else {
            content
        }
    }
}
