import SwiftUI

/// Main screen: blocks from the arrangement's layout (`layouts/today-*.layout.json`), refreshed every
/// minute so "now" and chains move. The pool and the timeline both pull to refresh (full sync).
/// Top left: This week (the review) and the problems badge; top right: new task and search, in the app's own bar of
/// glass bubbles with the day's name midway between them. In landscape the same buttons stand in a column along the physical top, each where it is upright on the
/// physical screen (see `PhysicalBottom`); the layout is the landscape one from settings. The arrows next to the day's name
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
    @Environment(\.physicalBottom) private var physicalBottom
    @State private var pendingAction: PendingAction?
    @State private var dayOffset = 0
    @State private var dragX: CGFloat = 0
    @State private var width: CGFloat = 0
    @State private var page = 0
    @State private var pageDrag: CGFloat = 0
    @State private var taskDrag = TaskDragState()

    private var isLandscape: Bool { physicalBottom != nil }

    var body: some View {
        VStack(spacing: 0) {
            if !isLandscape { portraitBar }
            HStack(alignment: .top, spacing: 0) {
                if physicalBottom == .trailing { landscapeColumn(bottom: .trailing) }
                content
                if physicalBottom == .leading { landscapeColumn(bottom: .leading) }
            }
        }
        .background(tokens.color(.screenBackground))
        .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { width = $0 }
        // Today draws its own bar (the same glass bubbles as the system one) so the day's name stands exactly between
        // the button groups, whatever their widths and the text size.
        .toolbar(.hidden, for: .navigationBar)
        .actionConfirmation($pendingAction) { handler.run($0.action, taskName: $0.taskName) }
        .environment(taskDrag)
        .onChange(of: router.todayTaps) { if dayOffset != 0 { withAnimation(tokens.animation) { dayOffset = 0 } } }
    }

    /// Turned sideways, Today has its own arrangement.
    private var arrangement: AppSettings.TodayArrangement {
        isLandscape ? model.settings.today.landscapeArrangement : model.settings.today.arrangement
    }

    private var layout: ScreenLayout { model.config.todayLayout(for: arrangement, landscape: isLandscape) }
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
                ScreenLayoutView(layout: layout, page: page, pageDrag: pageDrag, edgeInset: tokens.space(.screenHorizontal), onTurn: turn) { id in
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
            .onChange(of: arrangement) { page = 0 }
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

    /// The arrows around the shown day's name; on another day, tapping the name goes back to today.
    private var dayNavigation: DayNavigation {
        DayNavigation(dayOffset: dayOffset, onStep: changeDay) { withAnimation(tokens.animation) { dayOffset = 0 } }
    }

    /// The phone lying sideways: the bar's buttons in a column along the physical top, each where it is on the
    /// physical screen upright (the right end of the bar at the physical right, the arrows pointing the same way).
    private func landscapeColumn(bottom: HorizontalEdge) -> some View {
        VStack(spacing: tokens.space(.groupGap)) {
            ForEach(PhysicalBottom.physicalOrder(LandscapeSlot.allCases, bottom: bottom), id: \.self) { slot in
                switch slot {
                case .leading: bubble(.vertical) { TodayButtons(placement: .leading, bottom: bottom) }
                case .day: Spacer(minLength: 0); dayNavigation; Spacer(minLength: 0)
                case .trailing: bubble(.vertical) { TodayButtons(placement: .trailing, bottom: bottom) }
                }
            }
        }
        // As far from the physical sides as the bubbles upright: measured from the screen edges in both turns.
        .padding(.vertical, tokens.space(.screenHorizontal))
        .ignoresSafeArea(.container, edges: .vertical)
    }

    /// A group of bar buttons in the glass capsule the system draws around them upright.
    private func bubble(_ axis: Axis, @ViewBuilder _ buttons: () -> some View) -> some View {
        let layout = axis == .horizontal ? AnyLayout(HStackLayout(spacing: tokens.space(.barButtonGap)))
            : AnyLayout(VStackLayout(spacing: tokens.space(.barButtonGap)))
        return layout { buttons() }
            .buttonStyle(.plain)
            .foregroundStyle(tokens.color(.primaryText))
            .glassBubble()
    }

    /// The bar upright: the button groups at the edges, the day's name with its arrows midway between them.
    private var portraitBar: some View {
        HStack(spacing: 0) {
            bubble(.horizontal) { TodayButtons(placement: .leading) }
            Spacer(minLength: tokens.space(.chipGap))
            dayNavigation
            Spacer(minLength: tokens.space(.chipGap))
            bubble(.horizontal) { TodayButtons(placement: .trailing) }
        }
        .padding(.horizontal, tokens.space(.screenHorizontal))
        .padding(.top, tokens.space(.todayBarTop))
        .padding(.bottom, tokens.space(.todayBarBottom))
    }

    /// The bar upright, from the physical left to the physical right.
    private enum LandscapeSlot: CaseIterable { case leading, day, trailing }

    /// Blocks along a horizontal axis all reach the bottom; along a vertical one only the last does.
    private static func touchesBottom(_ id: TodayBlockID, in layout: ScreenLayout) -> Bool {
        layout.axis == .horizontal || layout.blocks.last?.block == id
    }

    private var handler: TaskActionHandler {
        TaskActionHandler(model: model, router: router, openURL: openURL) { pendingAction = $0 }
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
