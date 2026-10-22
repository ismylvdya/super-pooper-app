import SwiftUI

/// Untimed tasks of the day. Shows N rows (setting) plus a counter of hidden ones; scrolls.
struct PoolBlock: View {
    @Environment(AppModel.self) private var model
    @Environment(\.tokens) private var tokens
    let plan: DayPlan
    let handler: TaskActionHandler
    @State private var rowHeights: [String: CGFloat] = [:]

    var body: some View {
        VStack(alignment: .leading, spacing: tokens.space(.poolRowGap)) {
            if plan.pool.isEmpty {
                Text("pool.empty")
                    .font(tokens.font(.hint))
                    .foregroundStyle(tokens.color(.secondaryText))
                    .frame(maxWidth: .infinity, minHeight: tokens.size(.poolCounter))
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: tokens.space(.poolRowGap)) {
                        ForEach(plan.pool) { item in
                            row(item)
                                .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { rowHeights[item.id] = $0 }
                        }
                    }
                }
                .scrollBounceBehavior(.always)
                .frame(height: visibleHeight)
                .edgeFades()
                if hiddenCount > 0 {
                    Text(L10n.format("pool.more", hiddenCount))
                        .font(tokens.font(.poolCounter))
                        .foregroundStyle(tokens.color(.secondaryText))
                        .frame(maxWidth: .infinity)
                }
            }
        }
        .frame(idealWidth: tokens.size(.infoMaxWidth))
    }

    private var visibleCount: Int { max(model.settings.pool.visibleCount, 1) }
    private var hiddenCount: Int { max(plan.pool.count - visibleCount, 0) }

    private var visibleHeight: CGFloat {
        let rows = plan.pool.prefix(visibleCount)
        let heights = rows.map { rowHeights[$0.id] ?? tokens.size(.poolRowEstimate) }
        return heights.reduce(0, +) + tokens.space(.poolRowGap) * CGFloat(max(rows.count - 1, 0))
    }

    private func row(_ item: DayItem) -> some View {
        TaskRowView(item: item, today: plan.today,
                    onToggle: { handler.toggle(item.id) },
                    onOpen: { handler.run(ActionRegistryLookup.open, taskName: item.id) })
            .padding(.vertical, tokens.space(.rowVertical) / 2)
            .padding(.horizontal, tokens.space(.plateInner) / 2)
            .background(tokens.color(.plateBackground), in: RoundedRectangle(cornerRadius: tokens.radius(.poolRow), style: .continuous))
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
