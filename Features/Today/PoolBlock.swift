import SwiftUI

/// Untimed tasks of the day, under the headers of the day's sections (Morning, Day, Evening and the user's own). Above
/// the timeline it shows N rows (setting) and a "+K more" counter that follows scrolling; beside it, it takes the full
/// height and has no counter. Rows can be dragged: within the pool to reorder it (today) and into another section (that
/// day only), onto the timeline to give a task a time (a habit sent here today gets its time back for today); a timed
/// task dragged here from the timeline loses its time, a habit's block leaves today's timeline. A task from a backlog
/// page comes into the pool of any day shown. A section is dragged whole by its header, within the pool only. The tab
/// bar's "+" dragged over any day's pool makes a row's room; let go, it opens the new task's page for that day, and today
/// the task takes that spot once made (another day has no order of its own: the pool's sort places it).
struct PoolBlock: View {
    @Environment(AppModel.self) private var model
    @Environment(Router.self) private var router
    @Environment(\.tokens) private var tokens
    @Environment(\.rules) private var rules
    @Environment(\.physicalBottom) private var physicalBottom
    @Environment(TaskDragState.self) private var dragState: TaskDragState?
    @Environment(PoolSelection.self) private var selection: PoolSelection?
    let plan: DayPlan
    let handler: TaskActionHandler
    /// Space under the block that belongs to the home indicator (the list scrolls under it).
    let bottomInset: CGFloat
    /// The edges of the list that lie under a system bar (`edgeFades`).
    let barEdges: Edge.Set
    @State private var rowHeights: [String: CGFloat] = [:]
    @State private var visibleRows: Set<String> = []
    @State private var rowMids: [String: CGFloat] = [:]
    @State private var headerMids: [String: CGFloat] = [:]
    @State private var headerHeights: [String: CGFloat] = [:]
    /// The rows and headers as they stood when the drag reached the pool. The rows that make room move, and measuring
    /// them again would pull the dragged task back to where it was: the order is read against this layout instead.
    @State private var dragLayout: PoolDropLayout?
    /// The block on the screen, where the dragged "+" is compared with it.
    @State private var screenFrame: CGRect = .zero
    private static let dropSpace = "poolDrop"

    private var drag: TaskDragState? { dragState }

    var body: some View {
        poolContent
            .coordinateSpace(.named(Self.dropSpace))
            .modifier(PoolDropTarget(drag: drag, animation: tokens.animation, layout: dropLayout, canDrop: canDrop,
                                     onDrop: dropped, onSectionDrop: sectionDropped,
                                     onRefused: { model.refuseDrop($0.id, onto: .pool) }))
            .onGeometryChange(for: CGRect.self) { $0.frame(in: .global) } action: { screenFrame = $0 }
            .onChange(of: drag?.newItemPoint) { _, point in newItemMoved(to: point) }
            .onChange(of: drag?.draggedID ?? drag?.section) { _, dragged in if dragged == nil { dragLayout = nil } }
    }

    /// While something is dragged over the pool, the sections as the drop would make them.
    private var sections: [PoolSectionContent] {
        if let order = drag?.sectionOrder { return PoolArrangement.reordered(plan.sections, by: order) }
        guard let order = drag?.poolOrder, let item = drag?.item ?? newItemGap else { return plan.sections }
        let along = drag?.source.wormMembers.filter { $0 != item.id } ?? []
        let members = along.compactMap { name in plan.pool.first { $0.id == name } }
        return PoolArrangement.hovering(plan.sections, order: PoolDropOrder.keepingTogether(order, dragged: item.id, along: along),
                                        dragged: [item] + members, into: drag?.poolSection)
    }

    /// The room a dragged "+" takes among the rows: a row of its own, with nothing drawn in it.
    private var newItemGap: DayItem? {
        guard let drag, drag.source == .newItem else { return nil }
        var gap = DayItem(listed: TaskItem(id: .unsaved, name: TaskDragState.newItemGap, status: .thisWeek))
        gap.depth = drag.newItemSpot.depth
        return gap
    }

    private func dropLayout() -> PoolDropLayout {
        if let dragLayout { return dragLayout }
        let layout = PoolDropLayout(
            rows: plan.sections.flatMap { section in
                section.items.compactMap { item in rowMids[item.id].map { PoolDropOrder.Row(id: item.id, midY: Double($0), section: section.id) } }
            },
            headers: plan.sections.compactMap { section in headerMids[section.id].map { SectionDropOrder.Header(id: section.id, midY: Double($0)) } })
        dragLayout = layout
        return layout
    }

    /// Today's pool takes its own rows and the timeline's blocks; any day's a backlog page's tasks.
    private func canDrop(_ item: DayItem, from source: TaskDragState.Source) -> Bool {
        switch source {
        case .pool: plan.isToday
        case .timeline(let slot): plan.isToday && model.canDropInPool(item.id, slot: slot)
        case .backlog: model.canBringFromBacklog(item.id)
        case .worm: plan.isToday
        case .section, .newItem: false
        }
    }

    private func dropped(_ item: DayItem, from source: TaskDragState.Source, order: [String], section: String?) {
        Haptics.play(.drop)
        let day = plan.today
        let isToday = plan.isToday
        if let section, isToday, source.wormMembers.isEmpty { model.moveTask(item.id, toSection: section, poolOrder: order, on: day) }
        switch source {
        // The pool's own order is today's only.
        case .pool: if isToday && section == nil { model.setManualOrder(order) }
        case .timeline(let slot): Task { await model.unschedule(item.id, slot: slot, poolOrder: order, on: day) }
        case .backlog: Task { await model.bringFromBacklog(item.id, to: day, poolOrder: isToday ? order : nil) }
        case .worm(_, let members):
            model.moveTasks(members, toSection: section, poolOrder: PoolDropOrder.keepingTogether(order, dragged: item.id, along: members),
                            on: day)
        case .section, .newItem: break
        }
    }

    /// The dragged "+" over a pool: rows make room under it and letting go opens the new task's page for the spot.
    private func newItemMoved(to point: CGPoint?) {
        guard let drag, let point else {
            dragLayout = nil
            return
        }
        guard screenFrame.contains(point) else {
            if drag.poolOrder != nil { withAnimation(tokens.animation) { drag.leavePool() } }
            drag.clearNewItemLanding(Self.dropSpace)
            return
        }
        drag.turnAfterDwell(.block(.pool), seconds: rules.gestures.newItemTurnDwellSeconds)
        let layout = dropLayout()
        let spot = PoolDropOrder.drop(rows: layout.rows, headers: layout.headers, dragged: TaskDragState.newItemGap,
                                      at: Double(point.y - screenFrame.minY))
        // Over the right part of the pool the new task is the row above's subtask; crossing over is a step to feel.
        let asSubtask = NewItemNesting.isSubtaskSide(x: Double(point.x), poolMinX: Double(screenFrame.minX), poolWidth: Double(screenFrame.width),
                                                     share: rules.gestures.subtaskShare)
        let nesting = NewItemNesting.spot(order: spot.order, gap: TaskDragState.newItemGap, pool: plan.pool, asSubtask: asSubtask)
        // Another day's pool has no headers, so no spot names a section: the room opens in its one list.
        let moved = withAnimation(tokens.animation) { drag.hover(poolOrder: spot.order, section: spot.section ?? plan.sections.first?.id) }
        let above = spot.order.firstIndex(of: TaskDragState.newItemGap).flatMap { $0 > 0 ? spot.order[$0 - 1] : nil }
        drag.newItemAbove = plan.pool.first { $0.id == above && !$0.isHabit }?.id
        let nested = nesting != drag.newItemSpot
        if nested { withAnimation(tokens.animation) { drag.newItemSpot = nesting } }
        if moved || nested { Haptics.play(.dragStep) }
        drag.setNewItemLanding(Self.dropSpace) { newItemDropped(order: spot.order, section: spot.section, nesting: nesting) }
    }

    private func newItemDropped(order: [String], section: String?, nesting: NewItemNesting.Spot) {
        Haptics.play(.drop)
        let placement: NewItemPlacement = nesting.parent.map { .subtask(of: $0, index: nesting.index, day: plan.today) }
            ?? .pool(order: order, section: section, day: plan.today)
        router.openNewItem(NewItemSeed(kind: .task, placement: placement, estimate: drag?.releasedEstimate))
    }

    private func sectionDropped(_ id: String, order: [String]) {
        Haptics.play(.drop)
        model.moveSection(id, order: order, on: plan.today)
    }

    private var poolContent: some View {
        VStack(alignment: .leading, spacing: tokens.space(.poolRowGap)) {
            if plan.pool.isEmpty {
                Text("pool.empty")
                    .secondaryText(.hint)
                    .frame(maxWidth: .infinity, minHeight: tokens.size(.poolCounter))
                if fillsHeight { Spacer(minLength: 0) }
            } else {
                list
                    .frame(height: fillsHeight ? nil : visibleHeight)
                    .frame(maxHeight: fillsHeight ? .infinity : nil)
                if !fillsHeight { counter }
            }
        }
        .frame(idealWidth: tokens.size(.poolWidth))
    }

    /// By the arrangement Today has now: lying sideways it has its own.
    private var fillsHeight: Bool {
        let today = model.settings.today
        return !model.settings.poolUsesVisibleCount(in: physicalBottom == nil ? today.arrangement : today.landscapeArrangement)
    }
    private var visibleCount: Int { max(model.settings.pool.visibleCount, 1) }

    private var list: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: tokens.space(.poolRowGap)) {
                let shown = sections
                ForEach(shown) { section in
                    let isGap = drag?.isSectionGap(section.id) == true
                    if section.hasHeader {
                        PoolSectionHeader(section: section, isFirst: section.id == shown.first?.id, drag: selection?.isOn == true ? nil : drag, canRename: selection?.isOn != true) {
                            model.renameSection(section.id, to: $0, on: plan.today)
                        }
                            .dropGap(isGap)
                            .onGeometryChange(for: CGRect.self) { $0.frame(in: .named(Self.dropSpace)) } action: { frame in
                                headerMids[section.id] = frame.midY
                                headerHeights[section.id] = frame.height
                            }
                    }
                    // One plate for a whole routine or worm; each row keeps its own tap and long press. A worm's member drags
                    // the whole worm.
                    ForEach(PoolSegments.make(section.items, worms: plan.worms)) { segment in
                        let source = dragSource(of: segment)
                        PoolSegmentView(segment: segment) { item, plate in tracked(row(item, plate: .pool(plate), source: source), item) }
                            .dropGap(isGap)
                            .modifier(WormElement(isWorm: segment.wormID != nil))
                    }
                }
            }
        }
        // Scrolled to the end, the last row clears the tab bar.
        .contentMargins(.bottom, bottomInset + tokens.space(.scrollEndRoom), for: .scrollContent)
        .scrollBounceBehavior(.always)
        .scrollIndicators(.hidden)
        .syncsOnPull()
        .edgeFades(bottomExtension: bottomInset, barEdges: barEdges)
        .liftRoom()
    }

    /// Rows after the last visible one.
    private var hiddenBelow: Int {
        let lastVisible = plan.pool.lastIndex { visibleRows.contains($0.id) } ?? (visibleCount - 1)
        return max(plan.pool.count - lastVisible - 1, 0)
    }

    @ViewBuilder private var counter: some View {
        if hiddenBelow > 0 {
            Text(L10n.format("pool.more", hiddenBelow))
                .font(tokens.font(.poolCounter))
                .foregroundStyle(tokens.color(.secondaryText))
                .chipInsets()
                .systemLook(.floatingCapsule)
                .frame(maxWidth: .infinity)
                .allowsHitTesting(false)
        }
    }

    /// The first N rows with the headers above them.
    private var visibleHeight: CGFloat {
        let estimate = CGFloat(rules.layoutEstimates.poolRowHeight)
        var remaining = visibleCount
        var heights: [CGFloat] = []
        for section in plan.sections where remaining > 0 {
            if section.hasHeader { heights.append(headerHeights[section.id] ?? estimate) }
            heights += section.items.prefix(remaining).map { rowHeights[$0.id] ?? estimate }
            remaining -= min(remaining, section.items.count)
        }
        return heights.reduce(0, +) + tokens.space(.poolRowGap) * CGFloat(max(heights.count - 1, 0))
    }

    /// The row of a task dragged over the pool keeps an empty gap the others part around (`TaskDragState.isGap`).
    @ViewBuilder private func row(_ item: DayItem, plate: PoolRowContent.PlateKind, source: TaskDragState.Source) -> some View {
        if item.id == TaskDragState.newItemGap {
            NewItemGapPlate(depth: item.depth, extraLines: drag?.newItemEstimate.map(rules.pool.extraLines(forEstimate:)) ?? 0)
        } else {
            PoolRow(item: item, isToday: plan.isToday, isCompact: fillsHeight, plate: plate, handler: handler,
                    dragSource: selectionSource ?? source, poolDay: plan.today,
                    stackTop: selection.flatMap { selection in plan.pool.first { selection.isSelected($0.id) } },
                    guide: guides[item.id])
                .dropGap(drag?.isGap(item.id) == true)
        }
    }

    /// The lines from parents to their subtasks, while no task is dragged over the pool (the rows part then).
    private var guides: [String: SubtaskGuide] {
        drag?.poolOrder == nil ? SubtaskGuides.guides(of: plan.pool) : [:]
    }

    /// In Select mode a drag carries all the picked tasks, in the pool's order.
    private var selectionSource: TaskDragState.Source? {
        guard let selection, selection.isOn else { return nil }
        return TaskDragState.selection(plan.pool.map(\.id).filter(selection.isSelected))
    }

    private func dragSource(of segment: PoolSegments.Segment) -> TaskDragState.Source {
        guard let id = segment.wormID else { return .pool }
        return .worm(id: id, members: segment.items.filter { $0.depth == 0 }.map(\.id))
    }

    private func tracked(_ view: some View, _ item: DayItem) -> some View {
        view
            .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { rowHeights[item.id] = $0 }
            .onGeometryChange(for: CGFloat.self) { $0.frame(in: .named(Self.dropSpace)).midY } action: { rowMids[item.id] = $0 }
            .onScrollVisibilityChange(threshold: rules.pool.rowVisibleShare) { visible in
                if visible { visibleRows.insert(item.id) } else { visibleRows.remove(item.id) }
            }
    }
}
