import SwiftUI

/// The pages of Tasks (`TasksPageStrip`): the backlog pages opened left of the pool, then the day's blocks (each its own
/// page when the layout is paged, else all of Today as one page). The first page pulled right past its edge shows the
/// next backlog list's icon (`TodayPager.sidePull`).
struct TasksStrip: View {
    @Environment(AppModel.self) private var model
    @Environment(\.tokens) private var tokens
    @Environment(\.rules) private var rules
    @Environment(\.screenLayoutMetrics) private var metrics
    let layout: ScreenLayout
    let pages: [TasksPage]
    let pager: TodayPager
    let plan: DayPlan
    let handler: TaskActionHandler
    let bottomInset: CGFloat
    let isLandscape: Bool
    let edgeInset: CGFloat
    let fade: Double
    let onTurn: (Int) -> Void

    var body: some View {
        PagedStack(pages: pages, spacing: metrics.spacing(of: layout), peeks: pages.map(peek), edgeInset: edgeInset,
                   home: TasksPageStrip.homeIndex(layout: layout, opened: pager.openedBacklog), page: pager.page,
                   drag: pager.pageDrag, pull: pager.sidePull, edgeLabel: edgeLabel, onTurn: onTurn) { page in
            switch page {
            case .backlog(let id):
                if let list = model.config.lists.backlogList(id) {
                    BacklogPage(list: list, plan: plan, handler: handler, bottomInset: bottomInset,
                                barEdges: barEdges(reachesBottom: true), edgeInset: edgeInset)
                }
            case .block(let id): block(id)
            case .today: ScreenLayoutView(layout: layout, edgeInset: edgeInset) { block($0) }
            }
        }
        .overlay(alignment: .leading) {
            let lists = model.backlogLists
            if pager.sidePull > 0, lists.indices.contains(pager.openedBacklog) {
                PullIndicator(icon: lists[pager.openedBacklog].icon, pull: pager.sidePull, threshold: rules.gestures.sidePullThreshold,
                              isArmed: pager.isPullArmed, axis: .horizontal)
            }
        }
    }

    private func block(_ id: TodayBlockID) -> some View {
        let reachesBottom = layout.axis == .horizontal || layout.blocks.last?.block == id
        return TodayBlock(id: id, plan: plan, handler: handler, bottomInset: reachesBottom ? bottomInset : 0,
                          barEdges: barEdges(reachesBottom: reachesBottom))
            .daySlide(pager.daySlide, fade: fade)
    }

    /// Upright, the system tab bar lies over the bottom of a page that reaches the screen's bottom.
    private func barEdges(reachesBottom: Bool) -> Edge.Set {
        reachesBottom && !isLandscape ? .bottom : []
    }

    private func peek(_ page: TasksPage) -> CGFloat {
        guard case .block(let id) = page, let slot = layout.blocks.first(where: { $0.block == id }) else { return 0 }
        return metrics.peek(of: slot, in: layout, edgeInset: edgeInset)
    }

    private func edgeLabel(_ page: TasksPage) -> Text {
        switch page {
        case .backlog(let id):
            Text(L10n.format("today.page.list", L10n.string(model.config.lists.backlogList(id)?.title ?? id)))
        case .block(let id): TodayPageEdge.label(id)
        case .today: TodayPageEdge.label(.pool)
        }
    }
}

private extension View {
    /// The block follows the day swipe inside its own area; at rest nothing is clipped, so lifted plates
    /// still reach over the margins.
    func daySlide(_ offset: CGFloat, fade: Double) -> some View {
        modifier(DaySlide(offset: offset, fade: fade))
    }
}

private struct DaySlide: ViewModifier {
    @Environment(\.liftRoom) private var liftRoom
    let offset: CGFloat
    let fade: Double

    func body(content: Content) -> some View {
        content
            .offset(x: offset)
            .opacity(fade)
            .clipShape(Rectangle().inset(by: offset == 0 ? -liftRoom.sides : 0))
    }
}
