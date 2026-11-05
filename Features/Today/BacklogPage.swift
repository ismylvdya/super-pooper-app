import SwiftUI

/// A backlog page left of the pool (Soon, Half year, Someday): the list's tasks for the day shown, on the pool's plates,
/// with the pool's tap and long-press menu; each can be dragged to another page, into the pool or onto the timeline.
/// A task dragged here takes the list's level, and the rows part where the list will hold it; a row dragged off the page
/// closes up, as in the pool.
struct BacklogPage: View {
    @Environment(AppModel.self) private var model
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
    private static let dropSpace = "backlogDrop"

    var body: some View {
        let items = rows
        ScrollView {
            LazyVStack(alignment: .leading, spacing: tokens.space(.poolRowGap)) {
                ForEach(items) { item in
                    PoolRow(item: item, isToday: false, isCompact: true, handler: handler, dragSource: .backlog(list.id))
                        .onGeometryChange(for: CGFloat.self) { $0.frame(in: .named(Self.dropSpace)).midY } action: { rowMids[item.id] = $0 }
                        .dropGap(drag?.isBacklogLanding(item.id, on: list.id) == true)
                        .closedUp(drag?.isBacklogGap(item.id, on: list.id) == true, gap: tokens.space(.poolRowGap))
                }
            }
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
                          })
    }

    /// The list's tasks; while a task from elsewhere is over the page, it too, at the end of the list.
    private var rows: [DayItem] {
        let tasks = model.backlogTasks(list, plan: plan)
        var items = tasks.map(DayItem.init(listed:))
        if let order = drag?.backlogOrder {
            let place = Dictionary(order.enumerated().map { ($1, $0) }, uniquingKeysWith: { first, _ in first })
            items.sort { (place[$0.id] ?? .max) < (place[$1.id] ?? .max) }
        }
        if let dragged = drag?.item, drag?.isBacklogLanding(dragged.id, on: list.id) == true,
           !tasks.contains(where: { $0.name.isSameNoteName(as: dragged.id) }) {
            items.append(DayItem(listed: dragged.task))
        }
        return items
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

    func body(content: Content) -> some View {
        if let drag {
            content.onDrop(of: TaskDragState.types, delegate: BacklogDropDelegate(drag: drag, list: list, animation: animation,
                                                                                canDrop: canDrop, onDrop: onDrop, onRefused: onRefused,
                                                                                rows: rows, onReorder: onReorder))
        } else {
            content
        }
    }
}
