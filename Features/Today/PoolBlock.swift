import SwiftUI

/// Untimed tasks of the day. Above the timeline it shows N rows (setting) and a "+K more" counter
/// that follows scrolling; beside it, it takes the full height and has no counter. Today's rows can be
/// dragged: within the pool to reorder it, onto the timeline to give a task a time; a timed task dragged
/// here from the timeline loses its time.
struct PoolBlock: View {
    @Environment(AppModel.self) private var model
    @Environment(\.tokens) private var tokens
    @Environment(TaskDragState.self) private var drag: TaskDragState?
    let plan: DayPlan
    let handler: TaskActionHandler
    /// Space under the block that belongs to the home indicator (the list scrolls under it).
    let bottomInset: CGFloat
    @State private var rowHeights: [String: CGFloat] = [:]
    @State private var visibleRows: Set<String> = []
    @State private var rowMids: [String: CGFloat] = [:]
    private static let dropSpace = "poolDrop"

    var body: some View {
        poolContent
            .coordinateSpace(.named(Self.dropSpace))
            .modifier(PoolDropTarget(drag: plan.isToday ? drag : nil, animation: tokens.animation, rows: dropRows, onDrop: dropped))
    }

    /// While a task is dragged over the pool, the rows in the order it would make.
    private var items: [DayItem] {
        guard let order = drag?.poolOrder else { return plan.pool }
        return order.compactMap { id in plan.pool.first { $0.id == id } ?? (drag?.item?.id == id ? drag?.item : nil) }
    }

    private func dropRows() -> [PoolDropOrder.Row] {
        plan.pool.compactMap { item in rowMids[item.id].map { PoolDropOrder.Row(id: item.id, midY: Double($0)) } }
    }

    private func dropped(_ item: DayItem, from source: TaskDragState.Source, order: [String]) {
        Haptics.play(.light)
        switch source {
        case .pool: model.setManualOrder(order)
        case .timeline: Task { await model.unschedule(item.id, poolOrder: order) }
        }
    }

    private var poolContent: some View {
        VStack(alignment: .leading, spacing: tokens.space(.poolRowGap)) {
            if plan.pool.isEmpty {
                Text("pool.empty")
                    .font(tokens.font(.hint))
                    .foregroundStyle(tokens.color(.secondaryText))
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
                ForEach(PoolSegments.make(items)) { segment in
                    if segment.isRoutine {
                        // One plate for the whole routine; each habit keeps its own tap and long press.
                        VStack(alignment: .leading, spacing: 0) {
                            ForEach(segment.items) { item in tracked(row(item, plate: .bare), item) }
                        }
                        .background(tokens.color(.plateBackground),
                                    in: RoundedRectangle(cornerRadius: tokens.radius(.poolRow), style: .continuous))
                        .clipShape(RoundedRectangle(cornerRadius: tokens.radius(.poolRow), style: .continuous))
                    } else if let item = segment.items.first {
                        tracked(row(item, plate: .pool), item)
                    }
                }
            }
        }
        .contentMargins(.bottom, bottomInset, for: .scrollContent)
        .scrollBounceBehavior(.always)
        .scrollIndicators(.hidden)
        .refreshable { await model.sync(announce: true) }
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
                .padding(.horizontal, tokens.space(.chipHorizontal))
                .padding(.vertical, tokens.space(.chipVertical))
                .background(.regularMaterial, in: Capsule())
                .frame(maxWidth: .infinity)
                .allowsHitTesting(false)
        }
    }

    private var visibleHeight: CGFloat {
        let rows = plan.pool.prefix(visibleCount)
        let heights = rows.map { rowHeights[$0.id] ?? tokens.size(.poolRowEstimate) }
        return heights.reduce(0, +) + tokens.space(.poolRowGap) * CGFloat(max(rows.count - 1, 0))
    }

    private func row(_ item: DayItem, plate: PoolRowContent.PlateKind) -> some View {
        PoolRow(item: item, today: plan.today, isToday: plan.isToday, isCompact: fillsHeight, plate: plate, handler: handler,
                dragSource: plan.isToday ? .pool : nil)
    }

    private func tracked(_ view: some View, _ item: DayItem) -> some View {
        view
            .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { rowHeights[item.id] = $0 }
            .onGeometryChange(for: CGFloat.self) { $0.frame(in: .named(Self.dropSpace)).midY } action: { rowMids[item.id] = $0 }
            .onScrollVisibilityChange(threshold: 0.5) { visible in
                if visible { visibleRows.insert(item.id) } else { visibleRows.remove(item.id) }
            }
    }
}

/// A task in a rounded plate — the same look in the pool and on the timeline. In the pool the plate
/// grows with the estimate (a long task takes more room); the long-press highlight is the plate itself.
struct PoolRow: View {
    @Environment(\.tokens) private var tokens
    @Environment(\.rules) private var rules
    let item: DayItem
    let today: LocalDate
    var isToday = true
    var isCompact = false
    var plate: PoolRowContent.PlateKind = .pool
    let handler: TaskActionHandler
    var dragSource: TaskDragState.Source?

    var body: some View {
        let lines = rules.pool.extraLines(forEstimate: rules.day.estimate(of: item.task))
        PoolRowContent(item: item, today: today, isToday: isToday, isCompact: isCompact, plate: plate,
                       minimumHeight: CGFloat(lines) * tokens.uiFont(.taskTitle).lineHeight, handler: handler,
                       dragSource: dragSource)
            // A subtask sits under its parent, shifted right.
            .padding(.leading, CGFloat(item.depth) * tokens.space(.subtaskIndent))
    }
}

/// The row with its tap, title, long-press menu and drag wiring, on its plate.
struct PoolRowContent: View {
    enum PlateKind {
        case pool
        /// Inside a shared routine plate: the row's own padding, no plate of its own.
        case bare
        case slot(isPast: Bool, isCompact: Bool)
    }

    @Environment(\.tokens) private var tokens
    @Environment(\.actions) private var actions
    @Environment(TaskDragState.self) private var drag: TaskDragState?
    let item: DayItem
    let today: LocalDate
    var isToday = true
    var isCompact = true
    var titleFont: Font?
    var showsDetails = true
    var titleLineLimit: Int?
    var titleLineHeight: CGFloat?
    var plate: PlateKind = .pool
    /// Extra height under the content (pool rows of long tasks).
    var minimumHeight: CGFloat = 0
    let handler: TaskActionHandler
    /// Where a drag of this row starts from; nil = it cannot be dragged.
    var dragSource: TaskDragState.Source?

    var body: some View {
        let row = TaskRowView(item: item, today: today, titleFont: titleFont, showsDetails: showsDetails, isCompact: isCompact,
                              titleLineLimit: titleLineLimit, titleLineHeight: titleLineHeight,
                              onOpen: { handler.run(actions.definition(.open), taskName: item.id) })
        Group {
            switch plate {
            case .pool:
                VStack(alignment: .leading, spacing: 0) {
                    row
                    Spacer(minLength: minimumHeight)
                }
                .taskPlate(isDone: item.isDone)
            case .bare:
                VStack(alignment: .leading, spacing: 0) {
                    row
                    Spacer(minLength: minimumHeight)
                }
                .padding(.vertical, tokens.space(.rowVertical) / 2)
                .padding(.horizontal, tokens.space(.plateInner) / 2)
                .background(tokens.color(.plateBackground))
            case .slot(let isPast, let isCompact):
                row.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading).slotPlate(isPast: isPast, isCompact: isCompact)
            }
        }
        .contentShape(.contextMenuPreview, RoundedRectangle(cornerRadius: tokens.radius(plateRadius), style: .continuous))
        .contextMenu {
            ActionMenuContent(menu: item.isHabit ? .habitContext : .taskContext, item: item, isToday: isToday) {
                handler.handle($0, taskName: item.id)
            }
        }
        .taskDragSource(item, from: dragSource ?? .pool, drag: drag, isOn: dragSource != nil)
    }

    private var plateRadius: RadiusToken {
        if case .slot(_, true) = plate { return .widgetItem }
        return .poolRow
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
