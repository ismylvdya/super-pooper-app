import SwiftUI

/// The pages of Tasks (`TasksPageStrip`): the backlog pages opened left of the pool, then the day's blocks (each its own
/// page when the layout is paged, else all of Today as one page). The leftmost page reached, pulled right past its edge,
/// shows the next backlog list's icon (`TodayPager.sidePull`); a list shown keeps a part of each neighbour in sight.
struct TasksStrip: View {
    @Environment(AppModel.self) private var model
    @Environment(\.tokens) private var tokens
    @Environment(\.rules) private var rules
    @Environment(\.screenLayoutMetrics) private var metrics
    @Environment(\.pagePeeks) private var pagePeeks
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
    /// Where the neighbours' edges are, for a row the list engine carries (`TasksCarry`).
    var onEdgeFrame: ((Int, CGRect?) -> Void)?

    var body: some View {
        PagedStack(pages: pages, spacing: max(edgeInset, metrics.spacing(of: layout)), peekShares: pages.map(peek), edgeInset: edgeInset,
                   home: TasksPageStrip.homeIndex(layout: layout, opened: pager.openedBacklog),
                   listCount: pager.openedBacklog, listPeek: tokens.space(.backlogPeek), hiddenLists: pager.openedBacklog - pager.reachedBacklog, halves: layout.isHalves, page: pager.page,
                   drag: pager.pageDrag, pull: pager.sidePull, edgeLabel: edgeLabel, onTurn: onTurn, edgeDwell: rules.gestures.pageEdgeDwellSeconds,
                   onEdgeFrame: onEdgeFrame) { page in
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
        // Behind the pages: the pool's rows move over the icon as they are pulled away from it.
        .background(alignment: .leading) {
            let lists = model.backlogLists
            if pager.sidePull > 0, lists.indices.contains(pager.reachedBacklog) {
                let list = lists[pager.reachedBacklog]
                PullIndicator(icon: list.icon, pull: pager.sidePull, threshold: rules.gestures.sidePullThreshold,
                              isArmed: pager.isPullArmed, axis: .horizontal, margin: edgeInset)
                    // Midway between the bar's buttons and the tab bar: the strip reaches under the tab bar.
                    .padding(.bottom, bottomInset)
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

    /// How much of a day's page stays in sight beside the other: the share the settings give it (D-191).
    private func peek(_ page: TasksPage) -> Double {
        guard case .block(let id) = page else { return 0 }
        return pagePeeks.share(of: id)
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
