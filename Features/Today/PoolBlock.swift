import SwiftUI

/// Untimed tasks of the day. Above the timeline it shows N rows (setting); beside it, it takes
/// the full height. The "+K more" counter follows scrolling: it counts rows below the visible ones.
struct PoolBlock: View {
    @Environment(AppModel.self) private var model
    @Environment(\.tokens) private var tokens
    let plan: DayPlan
    let handler: TaskActionHandler
    /// Space under the block that belongs to the home indicator (the list scrolls under it).
    let bottomInset: CGFloat
    @State private var rowHeights: [String: CGFloat] = [:]
    @State private var visibleRows: Set<String> = []

    var body: some View {
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
                    .overlay(alignment: .bottom) { if fillsHeight { counter.padding(.bottom, bottomInset) } }
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
                ForEach(plan.pool) { item in
                    row(item)
                        .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { rowHeights[item.id] = $0 }
                        .onScrollVisibilityChange(threshold: 0.5) { visible in
                            if visible { visibleRows.insert(item.id) } else { visibleRows.remove(item.id) }
                        }
                }
            }
        }
        .contentMargins(.bottom, bottomInset + (fillsHeight ? tokens.size(.poolCounter) : 0), for: .scrollContent)
        .scrollBounceBehavior(.always)
        .edgeFades(bottomExtension: bottomInset)
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

    private func row(_ item: DayItem) -> some View {
        PoolRow(item: item, today: plan.today, isCompact: fillsHeight, handler: handler)
    }
}

/// A task in a rounded plate — the same look in the pool and on the timeline.
struct PoolRow: View {
    let item: DayItem
    let today: LocalDate
    var isCompact = false
    let handler: TaskActionHandler

    var body: some View {
        PoolRowContent(item: item, today: today, isCompact: isCompact, handler: handler).taskPlate()
    }
}

/// The row with its tap, title and long-press menu wiring, without the plate.
struct PoolRowContent: View {
    let item: DayItem
    let today: LocalDate
    var isCompact = true
    var titleFont: Font?
    var showsDetails = true
    var titleLineLimit: Int?
    let handler: TaskActionHandler

    var body: some View {
        TaskRowView(item: item, today: today, titleFont: titleFont, showsDetails: showsDetails, isCompact: isCompact,
                    titleLineLimit: titleLineLimit,
                    onToggle: { handler.toggle(item.id) },
                    onOpen: { handler.run(ActionRegistryLookup.open, taskName: item.id) })
            .contextMenu {
                ActionMenuContent(menu: item.isHabit ? .habitContext : .taskContext, item: item) {
                    handler.handle($0, taskName: item.id)
                }
            }
    }
}

/// The "open" action definition without a registry round trip in row closures.
enum ActionRegistryLookup {
    @MainActor static var open: ActionDefinition { BundledConfig.actions.definition(.open) }
}
