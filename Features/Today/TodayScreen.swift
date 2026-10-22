import SwiftUI

/// Main screen: blocks from `today.layout.json` (pool and timeline by default), refreshed every
/// minute so "now" and chains move. Pull-to-refresh (full sync) is set for every page in `RootView`.
struct TodayScreen: View {
    @Environment(AppModel.self) private var model
    @Environment(Router.self) private var router
    @Environment(\.tokens) private var tokens
    @Environment(\.icons) private var icons
    @Environment(\.openURL) private var openURL
    @State private var pendingAction: PendingAction?

    var body: some View {
        TimelineView(.periodic(from: .now, by: model.config.rules.timeline.refreshSeconds)) { _ in
            let plan = model.plan(at: model.clock.now)
            VStack(spacing: tokens.space(.titleBottom)) {
                Text("today.title")
                    .font(tokens.font(.pageTitle))
                    .frame(maxWidth: .infinity)
                ScreenLayoutView(layout: model.config.todayLayout) { id in
                    TodayBlock(id: id, plan: plan, handler: handler)
                }
            }
            .padding(.horizontal, tokens.space(.screenHorizontal))
        }
        .background(tokens.color(.screenBackground))
        .toolbar { toolbar }
        .navigationBarTitleDisplayMode(.inline)
        .actionConfirmation($pendingAction) { handler.run($0.action, taskName: $0.taskName) }
    }

    private var handler: TaskActionHandler {
        TaskActionHandler(model: model, router: router, openURL: openURL) { pendingAction = $0 }
    }

    @ToolbarContentBuilder private var toolbar: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            Button { router.open(.settings) } label: { Image(systemName: icons[.settings]) }
                .accessibilityLabel(Text("settings.title"))
        }
        ToolbarItemGroup(placement: .topBarTrailing) {
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
            Button("today.edit") { router.isReviewPresented = true }
                .fontWeight(.semibold)
                .accessibilityIdentifier("today.edit")
        }
    }
}

/// Maps layout block ids to block views. Unknown ids show a visible error instead of crashing.
struct TodayBlock: View {
    @Environment(\.tokens) private var tokens
    let id: String
    let plan: DayPlan
    let handler: TaskActionHandler

    var body: some View {
        switch id {
        case "pool": PoolBlock(plan: plan, handler: handler)
        case "timeline": TimelineBlock(plan: plan, handler: handler)
        default:
            Text(L10n.format("error.layout.unknownBlock", id))
                .font(tokens.font(.hint))
                .foregroundStyle(tokens.color(.problem))
        }
    }
}
