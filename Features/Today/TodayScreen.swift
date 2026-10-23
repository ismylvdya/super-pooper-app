import SwiftUI

/// Main screen: blocks from the arrangement's layout (`layouts/today-*.layout.json`), refreshed every
/// minute so "now" and chains move. The pool and the timeline both pull to refresh (full sync).
/// Top left: the morning review (edit the pool) and the problems badge; top right: search. In landscape
/// the bar is hidden and the same buttons stand in a column on the left.
struct TodayScreen: View {
    @Environment(AppModel.self) private var model
    @Environment(Router.self) private var router
    @Environment(\.tokens) private var tokens
    @Environment(\.icons) private var icons
    @Environment(\.openURL) private var openURL
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    @State private var pendingAction: PendingAction?

    private var isLandscape: Bool { verticalSizeClass == .compact }

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            if isLandscape {
                VStack(spacing: tokens.space(.groupGap)) {
                    TodayButtons(placement: .leading)
                    TodayButtons(placement: .trailing)
                }
                .padding(.leading, tokens.space(.screenHorizontal))
                .padding(.top, tokens.space(.headerToPlate))
            }
            content
        }
        .background(tokens.color(.screenBackground))
        .toolbar(isLandscape ? .hidden : .automatic, for: .navigationBar)
        .toolbar {
            ToolbarItemGroup(placement: .topBarLeading) { TodayButtons(placement: .leading) }
            ToolbarItemGroup(placement: .topBarTrailing) { TodayButtons(placement: .trailing) }
        }
        .navigationBarTitleDisplayMode(.inline)
        .actionConfirmation($pendingAction) { handler.run($0.action, taskName: $0.taskName) }
    }

    private var content: some View {
        GeometryReader { geometry in
            let layout = model.config.todayLayout(for: model.settings.today.arrangement)
            let bottomInset = geometry.safeAreaInsets.bottom
            TimelineView(.periodic(from: .now, by: model.config.rules.timeline.refreshSeconds)) { _ in
                let plan = model.plan(at: model.clock.now)
                ScreenLayoutView(layout: layout) { id in
                    TodayBlock(id: id, plan: plan, handler: handler,
                               bottomInset: Self.touchesBottom(id, in: layout) ? bottomInset : 0)
                }
                .padding(.horizontal, tokens.space(.screenHorizontal))
                .padding(.top, tokens.space(.headerToPlate))
            }
            .ignoresSafeArea(.container, edges: .bottom)
        }
    }

    /// Blocks along a horizontal axis all reach the bottom; along a vertical one only the last does.
    private static func touchesBottom(_ id: String, in layout: ScreenLayout) -> Bool {
        layout.axis == .horizontal || layout.blocks.last?.block == id
    }

    private var handler: TaskActionHandler {
        TaskActionHandler(model: model, router: router, openURL: openURL) { pendingAction = $0 }
    }
}

/// The Today buttons: leading = morning review and problems badge, trailing = search.
struct TodayButtons: View {
    enum Placement { case leading, trailing }

    @Environment(AppModel.self) private var model
    @Environment(Router.self) private var router
    @Environment(\.tokens) private var tokens
    @Environment(\.icons) private var icons
    let placement: Placement

    var body: some View {
        switch placement {
        case .leading:
            Button { router.isReviewPresented = true } label: { Image(systemName: icons[.edit]) }
                .tint(.primary)
                .accessibilityLabel(Text("review.title"))
                .accessibilityIdentifier("today.review")
            if model.config.flags.problemBadge, model.problemCount > 0 {
                Button { router.isProblemsPresented = true } label: {
                    HStack(spacing: 4) {
                        Image(systemName: icons[.problem])
                        Text(verbatim: "\(model.problemCount)").font(tokens.font(.poolCounter))
                    }
                    .foregroundStyle(tokens.color(.problem))
                }
                .accessibilityLabel(Text("problems.title"))
            }
        case .trailing:
            Button { router.open(.search) } label: { Image(systemName: icons[.search]) }
                .tint(.primary)
                .accessibilityLabel(Text("search.title"))
                .accessibilityIdentifier("today.search")
        }
    }
}

/// Maps layout block ids to block views. Unknown ids show a visible error instead of crashing.
struct TodayBlock: View {
    @Environment(\.tokens) private var tokens
    let id: String
    let plan: DayPlan
    let handler: TaskActionHandler
    let bottomInset: CGFloat

    var body: some View {
        switch id {
        case "pool": PoolBlock(plan: plan, handler: handler, bottomInset: bottomInset)
        case "timeline": TimelineBlock(plan: plan, handler: handler, bottomInset: bottomInset)
        default:
            Text(L10n.format("error.layout.unknownBlock", id))
                .font(tokens.font(.hint))
                .foregroundStyle(tokens.color(.problem))
        }
    }
}
