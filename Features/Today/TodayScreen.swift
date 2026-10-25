import SwiftUI

/// Main screen: blocks from the arrangement's layout (`layouts/today-*.layout.json`), refreshed every
/// minute so "now" and chains move. The pool and the timeline both pull to refresh (full sync).
/// Top left: This week (the review) and the problems badge; top right: new task and search. In landscape
/// the bar is hidden and the same buttons stand in a column on the left. The arrows next to the day's name
/// slide the pool and the timeline together to yesterday / tomorrow (and further): another day shows its own
/// events, reminders, dated tasks and habits; its name, or the Today tab, brings back today. With the paged
/// arrangement a swipe turns between the pool and the timeline pages.
/// Tasks are dragged between the pool and the timeline (see `TaskDragState`).
struct TodayScreen: View {
    @Environment(AppModel.self) private var model
    @Environment(Router.self) private var router
    @Environment(\.tokens) private var tokens
    @Environment(\.icons) private var icons
    @Environment(\.openURL) private var openURL
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    @State private var pendingAction: PendingAction?
    @State private var dayOffset = 0
    @State private var dragX: CGFloat = 0
    @State private var width: CGFloat = 0
    /// The bar buttons grow with the text size, and so does the room they take.
    @ScaledMetric(relativeTo: .title3) private var barScale: CGFloat = 1
    @State private var page = 0
    @State private var pageDrag: CGFloat = 0
    @State private var taskDrag = TaskDragState()

    private var isLandscape: Bool { verticalSizeClass == .compact }

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            if isLandscape {
                VStack(spacing: tokens.space(.groupGap)) {
                    TodayButtons(placement: .leading)
                    TodayButtons(placement: .trailing)
                    dayNavigation(axis: .vertical)
                }
                .padding(.leading, tokens.space(.screenHorizontal))
                .padding(.top, tokens.space(.headerToPlate))
            }
            content
        }
        .background(tokens.color(.screenBackground))
        .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { width = $0 }
        .toolbar(isLandscape ? .hidden : .automatic, for: .navigationBar)
        .toolbar {
            ToolbarItemGroup(placement: .topBarLeading) { TodayButtons(placement: .leading) }
            ToolbarItem(placement: .principal) { dayNavigation(axis: .horizontal) }
            ToolbarItemGroup(placement: .topBarTrailing) { TodayButtons(placement: .trailing) }
        }
        .navigationBarTitleDisplayMode(.inline)
        .actionConfirmation($pendingAction) { handler.run($0.action, taskName: $0.taskName) }
        .environment(taskDrag)
        .onChange(of: router.todayTaps) { if dayOffset != 0 { withAnimation(tokens.animation) { dayOffset = 0 } } }
    }

    private var layout: ScreenLayout { model.config.todayLayout(for: model.settings.today.arrangement) }
    private var pageCount: Int { layout.isPaged ? layout.blocks.count : 1 }

    private func turn(to newPage: Int) {
        guard layout.isPaged, newPage != page, layout.blocks.indices.contains(newPage) else { return }
        withAnimation(tokens.animation) {
            page = newPage
            pageDrag = 0
        }
    }

    private var content: some View {
        GeometryReader { geometry in
            let layout = layout
            let bottomInset = geometry.safeAreaInsets.bottom
            TimelineView(.periodic(from: .now, by: model.config.rules.timeline.refreshSeconds)) { _ in
                let plan = model.plan(at: model.clock.now, dayOffset: dayOffset)
                let fade = 1 - min(abs(dragX) / geometry.size.width, 1) * tokens.opacity(.daySwipeFade)
                ScreenLayoutView(layout: layout, page: page, pageDrag: pageDrag, onTurn: turn) { id in
                    TodayBlock(id: id, plan: plan, handler: handler,
                               bottomInset: Self.touchesBottom(id, in: layout) ? bottomInset : 0)
                        .daySlide(dragX, fade: fade)
                }
                .padding(.horizontal, tokens.space(.screenHorizontal))
                .padding(.top, tokens.space(.headerToPlate))
                // An empty pool still takes the swipe.
                .contentShape(Rectangle())
            }
            .ignoresSafeArea(.container, edges: .bottom)
            .simultaneousGesture(daySwipe(width: geometry.size.width))
            .onAppear {
                taskDrag.turn = { block in
                    if let index = layout.blocks.firstIndex(where: { $0.block == block }) { turn(to: index) }
                }
            }
            .onChange(of: model.settings.today.arrangement) { page = 0 }
        }
    }

    /// On pages a horizontal drag moves them with the finger; far enough, it turns the page. Past the first or
    /// last page it does nothing: the day changes with the arrows.
    private func daySwipe(width: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: tokens.size(.daySwipeStart))
            .onChanged { value in
                guard TodaySwipe.isHorizontal(width: value.translation.width, height: value.translation.height,
                                              axisRatio: tokens.size(.daySwipeAxisRatio)),
                      TodaySwipe.page(forward: value.translation.width < 0, page: page, pageCount: pageCount) != nil else { return }
                pageDrag = value.translation.width
            }
            .onEnded { value in
                let distance = value.translation.width
                let isSwipe = TodaySwipe.isSwipe(width: distance, height: value.translation.height,
                                                 predictedWidth: value.predictedEndTranslation.width, containerWidth: width,
                                                 threshold: tokens.opacity(.daySwipeThreshold), axisRatio: tokens.size(.daySwipeAxisRatio))
                if isSwipe, let target = TodaySwipe.page(forward: distance < 0, page: page, pageCount: pageCount) {
                    turn(to: target)
                } else {
                    withAnimation(tokens.animation) { pageDrag = 0 }
                }
            }
    }

    /// Yesterday / tomorrow: the pool and the timeline slide out to the side and the other day slides in.
    private func changeDay(by step: Int) {
        withAnimation(.easeIn(duration: tokens.duration(.animation) / 2)) { dragX = step > 0 ? -width : width } completion: {
            dayOffset += step
            dragX = step > 0 ? width : -width
            withAnimation(.easeOut(duration: tokens.duration(.animation) / 2)) { dragX = 0 }
        }
    }

    /// The arrows around the shown day's name; on another day, tapping the name goes back to today. In the bar
    /// it gets exactly the room the side buttons leave (the bar never narrows its middle item): the long name
    /// ("Tomorrow, 26 Oct") if it fits, otherwise the short one ("Tomorrow"), shrinking if it has to.
    @ViewBuilder private func dayNavigation(axis: Axis) -> some View {
        let day = model.context().today.adding(days: dayOffset)
        let long = DayName.format(day, offset: dayOffset, calendar: model.calendar)
        let short = DayName.short(day, offset: dayOffset, calendar: model.calendar)
        switch axis {
        case .horizontal:
            ViewThatFits(in: .horizontal) {
                dayArrows(HStackLayout(spacing: tokens.space(.chipGap)), title: long, shrinks: false)
                dayArrows(HStackLayout(spacing: tokens.space(.chipGap)), title: short, shrinks: true)
            }
            .frame(width: max(width - tokens.size(.todayBarSideWidth) * barScale * 2, 0))
        case .vertical:
            dayArrows(VStackLayout(spacing: tokens.space(.chipGap)), title: short, shrinks: true)
        }
    }

    private func dayArrows(_ layout: some Layout, title: String, shrinks: Bool) -> some View {
        layout {
            Button { changeDay(by: -1) } label: { Image(systemName: icons[.previousDay]) }
                .accessibilityLabel(Text("today.previousDay"))
                .accessibilityIdentifier("today.previousDay")
            Button {
                withAnimation(tokens.animation) { dayOffset = 0 }
            } label: {
                Text(verbatim: title)
                    .font(tokens.font(.navTitle))
                    .lineLimit(1)
                    .minimumScaleFactor(shrinks ? tokens.size(.navTitleMin) / tokens.uiFont(.navTitle).pointSize : 1)
            }
            .accessibilityIdentifier("today.day")
            Button { changeDay(by: 1) } label: { Image(systemName: icons[.nextDay]) }
                .accessibilityLabel(Text("today.nextDay"))
                .accessibilityIdentifier("today.nextDay")
        }
        .tint(tokens.color(.accent))
    }

    /// Blocks along a horizontal axis all reach the bottom; along a vertical one only the last does.
    private static func touchesBottom(_ id: TodayBlockID, in layout: ScreenLayout) -> Bool {
        layout.axis == .horizontal || layout.blocks.last?.block == id
    }

    private var handler: TaskActionHandler {
        TaskActionHandler(model: model, router: router, openURL: openURL) { pendingAction = $0 }
    }
}

/// The Today buttons: leading = morning review and problems badge, trailing = new task and search.
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
            Button { router.isReviewPresented = true } label: { Image(systemName: icons[.review]) }
                .tint(tokens.color(.accent))
                .accessibilityLabel(Text("review.title"))
                .accessibilityIdentifier("today.review")
            if model.config.flags.problemBadge, model.problemCount > 0 {
                Button { router.isProblemsPresented = true } label: {
                    HStack(spacing: tokens.space(.badgeGap)) {
                        Image(systemName: icons[.problem])
                        Text(verbatim: "\(model.problemCount)").font(tokens.font(.poolCounter))
                    }
                    .foregroundStyle(tokens.color(.problem))
                }
                .accessibilityLabel(Text("problems.title"))
            }
        case .trailing:
            Button { router.open(.newTask) } label: { Image(systemName: icons[.newTask]) }
                .tint(tokens.color(.accent))
                .accessibilityLabel(Text("task.new.title"))
                .accessibilityIdentifier("today.newTask")
            Button { router.open(.search) } label: { Image(systemName: icons[.search]) }
                .tint(tokens.color(.accent))
                .accessibilityLabel(Text("search.title"))
                .accessibilityIdentifier("today.search")
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
    @Environment(\.tokens) private var tokens
    let offset: CGFloat
    let fade: Double

    func body(content: Content) -> some View {
        content
            .offset(x: offset)
            .opacity(fade)
            .clipShape(Rectangle().inset(by: offset == 0 ? -tokens.size(.liftOverhang) : 0))
    }
}

/// Maps layout block ids to block views (unknown ids stop the app at config loading).
struct TodayBlock: View {
    let id: TodayBlockID
    let plan: DayPlan
    let handler: TaskActionHandler
    let bottomInset: CGFloat

    var body: some View {
        switch id {
        case .pool: PoolBlock(plan: plan, handler: handler, bottomInset: bottomInset)
        case .timeline: TimelineBlock(plan: plan, handler: handler, bottomInset: bottomInset)
        }
    }
}
