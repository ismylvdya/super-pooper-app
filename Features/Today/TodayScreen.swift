import SwiftUI

/// Main screen: blocks from the arrangement's layout (`layouts/today-*.layout.json`), refreshed every
/// minute so "now" and chains move. Pull-to-refresh (full sync) lives only in the timeline; the pool has the pencil pull.
struct TodayScreen: View {
    @Environment(AppModel.self) private var model
    @Environment(Router.self) private var router
    @Environment(\.tokens) private var tokens
    @Environment(\.icons) private var icons
    @Environment(\.openURL) private var openURL
    @State private var pendingAction: PendingAction?
    @State private var isNewTaskPresented = false

    var body: some View {
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
        .background(tokens.color(.screenBackground))
        .toolbar { toolbar }
        .navigationBarTitleDisplayMode(.inline)
        .actionConfirmation($pendingAction) { handler.run($0.action, taskName: $0.taskName) }
        .newTaskPrompt(isPresented: $isNewTaskPresented) { router.open(.task($0)) }
    }

    /// Blocks along a horizontal axis all reach the bottom; along a vertical one only the last does.
    private static func touchesBottom(_ id: String, in layout: ScreenLayout) -> Bool {
        layout.axis == .horizontal || layout.blocks.last?.block == id
    }

    private var handler: TaskActionHandler {
        TaskActionHandler(model: model, router: router, openURL: openURL) { pendingAction = $0 }
    }

    @ToolbarContentBuilder private var toolbar: some ToolbarContent {
        ToolbarItemGroup(placement: .topBarLeading) {
            Button { router.open(.settings) } label: { Image(systemName: icons[.settings]) }
                .tint(.primary)
                .accessibilityLabel(Text("settings.title"))
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
        }
        ToolbarItemGroup(placement: .topBarTrailing) {
            Button { isNewTaskPresented = true } label: {
                Image(systemName: icons[.newTask])
            }
            .tint(.primary)
            .accessibilityLabel(Text("task.new.add"))
            .accessibilityIdentifier("task.new")
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
