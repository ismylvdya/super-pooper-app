import SwiftUI

/// Untimed tasks of the day. Above the timeline it shows N rows (setting) and a "+K more" counter
/// that follows scrolling; beside it, it takes the full height and has no counter. Today's rows can be
/// dragged: within the pool to reorder it, onto the timeline to give a task a time; a timed task dragged
/// here from the timeline loses its time.
struct PoolBlock: View {
    @Environment(AppModel.self) private var model
    @Environment(\.tokens) private var tokens
    @Environment(\.rules) private var rules
    @Environment(TaskDragState.self) private var drag: TaskDragState?
    let plan: DayPlan
    let handler: TaskActionHandler
    /// Space under the block that belongs to the home indicator (the list scrolls under it).
    let bottomInset: CGFloat
    @State private var rowHeights: [String: CGFloat] = [:]
    @State private var visibleRows: Set<String> = []
    @State private var rowMids: [String: CGFloat] = [:]
    /// The rows' middles as they stood when the drag reached the pool. The rows that make room move, and measuring
    /// them again would pull the dragged task back to where it was: the order is read against this layout instead.
    @State private var dragMids: [String: CGFloat]?
    private static let dropSpace = "poolDrop"

    var body: some View {
        poolContent
            .coordinateSpace(.named(Self.dropSpace))
            .modifier(PoolDropTarget(drag: plan.isToday ? drag : nil, animation: tokens.animation, rows: dropRows, onDrop: dropped))
            .onChange(of: drag?.item?.id) { _, dragged in if dragged == nil { dragMids = nil } }
    }

    /// While a task is dragged over the pool, the rows in the order it would make.
    private var items: [DayItem] {
        guard let order = drag?.poolOrder else { return plan.pool }
        return order.compactMap { id in plan.pool.first { $0.id == id } ?? (drag?.item?.id == id ? drag?.item : nil) }
    }

    private func dropRows() -> [PoolDropOrder.Row] {
        let mids = dragMids ?? rowMids
        if dragMids == nil { dragMids = rowMids }
        return plan.pool.compactMap { item in mids[item.id].map { PoolDropOrder.Row(id: item.id, midY: Double($0)) } }
    }

    private func dropped(_ item: DayItem, from source: TaskDragState.Source, order: [String]) {
        Haptics.play(.drop)
        switch source {
        case .pool: model.setManualOrder(order)
        case .timeline: Task { await model.unschedule(item.id, poolOrder: order) }
        }
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

    private var fillsHeight: Bool { !model.settings.poolUsesVisibleCount }
    private var visibleCount: Int { max(model.settings.pool.visibleCount, 1) }

    private var list: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: tokens.space(.poolRowGap)) {
                // One plate for a whole routine; each habit keeps its own tap and long press.
                ForEach(PoolSegments.make(items)) { segment in
                    PoolSegmentView(segment: segment) { item, plate in tracked(row(item, plate: .pool(plate)), item) }
                }
            }
        }
        // Scrolled to the end, the last row clears the tab bar.
        .contentMargins(.bottom, bottomInset + tokens.space(.scrollEndRoom), for: .scrollContent)
        .scrollBounceBehavior(.always)
        .scrollIndicators(.hidden)
        .syncsOnPull()
        .edgeFades(bottomExtension: bottomInset)
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
                .chipCapsule(.regularMaterial)
                .frame(maxWidth: .infinity)
                .allowsHitTesting(false)
        }
    }

    private var visibleHeight: CGFloat {
        let rows = plan.pool.prefix(visibleCount)
        let heights = rows.map { rowHeights[$0.id] ?? CGFloat(rules.layoutEstimates.poolRowHeight) }
        return heights.reduce(0, +) + tokens.space(.poolRowGap) * CGFloat(max(rows.count - 1, 0))
    }

    private func row(_ item: DayItem, plate: PoolRowContent.PlateKind) -> some View {
        PoolRow(item: item, isToday: plan.isToday, isCompact: fillsHeight, plate: plate, handler: handler,
                dragSource: plan.isToday ? .pool : nil)
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

/// The pool as a drop target (today only).
private struct PoolDropTarget: ViewModifier {
    let drag: TaskDragState?
    let animation: Animation
    let rows: () -> [PoolDropOrder.Row]
    let onDrop: (DayItem, TaskDragState.Source, [String]) -> Void

    func body(content: Content) -> some View {
        if let drag {
            content
                .contentShape(Rectangle())
                .onDrop(of: TaskDragState.types, delegate: PoolDropDelegate(drag: drag, animation: animation, rows: rows, onDrop: onDrop))
        } else {
            content
        }
    }
}
