import SwiftUI

/// Main screen: blocks from the arrangement's layout (`layouts/today-*.layout.json`), refreshed every
/// minute so "now" and chains move. The pool and the timeline both pull to refresh (full sync).
/// Top left: Soon (the review) and the problems badge; top right: new task and search, in the system navigation
/// bar with the day's name as its title (so the bar's buttons flow into a pushed page's, as on the other tabs). In landscape the same buttons stand in a column along the physical top, each where it is upright on the
/// physical screen (see `PhysicalBottom`); the layout is the landscape one from settings. The arrows next to the day's name
/// slide the pool and the timeline together to yesterday / tomorrow (and further): another day shows its own
/// events, reminders, dated tasks and habits; its name, or the Today tab, brings back today. With the paged
/// arrangement a swipe turns between the pool and the timeline pages.
/// Tasks are dragged between the pool and the timeline (see `TaskDragState`).
struct TodayScreen: View {
    @Environment(AppModel.self) private var model
    @Environment(Router.self) private var router
    @Environment(\.tokens) private var tokens
    @Environment(\.rules) private var rules
    @Environment(\.openURL) private var openURL
    @Environment(\.physicalBottom) private var physicalBottom
    @State private var pendingAction: PendingAction?
    @State private var width: CGFloat = 0
    @State private var pager = TodayPager()
    @State private var taskDrag = TaskDragState()

    private var isLandscape: Bool { physicalBottom != nil }

    var body: some View {
        VStack(spacing: 0) {
            HStack(alignment: .top, spacing: 0) {
                if physicalBottom == .trailing { landscapeColumn(bottom: .trailing) }
                content
                if physicalBottom == .leading { landscapeColumn(bottom: .leading) }
            }
        }
        .screenBackground()
        .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { width = $0 }
        // Upright, the system bar; lying sideways the buttons stand in their own column along the physical top.
        .toolbar(isLandscape ? .hidden : .visible, for: .navigationBar)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if !isLandscape {
                ToolbarItemGroup(placement: .topBarLeading) { TodayButtons(placement: .leading) }
                ToolbarItem(placement: .principal) { dayNavigation }
                ToolbarItemGroup(placement: .topBarTrailing) { TodayButtons(placement: .trailing) }
            }
        }
        .actionConfirmation($pendingAction) { handler.run($0.action, taskName: $0.taskName) }
        .environment(taskDrag)
        // A drag asks for a block; the pages of the layout shown now turn to it.
        .onChange(of: taskDrag.turnRequest) { _, block in
            guard let block else { return }
            if let index = layout.blocks.firstIndex(where: { $0.block == block }) { turn(to: index) }
            taskDrag.turnHandled()
        }
        .onChange(of: router.todayTaps) { pager.showToday(animation: tokens.animation) }
    }

    /// Turned sideways, Today has its own arrangement.
    private var arrangement: AppSettings.TodayArrangement {
        isLandscape ? model.settings.today.landscapeArrangement : model.settings.today.arrangement
    }

    private var layout: ScreenLayout { model.config.todayLayout(for: arrangement, landscape: isLandscape) }
    private var pageCount: Int { layout.isPaged ? layout.blocks.count : 1 }

    private func turn(to newPage: Int) {
        pager.turn(to: newPage, pageCount: pageCount, animation: tokens.animation)
    }

    private var content: some View {
        GeometryReader { geometry in
            let layout = layout
            let bottomInset = geometry.safeAreaInsets.bottom
            TimelineView(.periodic(from: .now, by: model.config.rules.timeline.refreshSeconds)) { _ in
                let plan = model.plan(at: model.clock.now, dayOffset: pager.dayOffset)
                let fade = 1 - min(abs(pager.daySlide) / geometry.size.width, 1) * tokens.opacity(.daySwipeFade)
                ScreenLayoutView(layout: layout, page: pager.page, pageDrag: pager.pageDrag, edgeInset: tokens.space(.screenHorizontal),
                                 onTurn: turn) { id in
                    let reachesBottom = Self.touchesBottom(id, in: layout)
                    TodayBlock(id: id, plan: plan, handler: handler, bottomInset: reachesBottom ? bottomInset : 0,
                               barEdges: reachesBottom && !isLandscape ? .bottom : [])
                        .daySlide(pager.daySlide, fade: fade)
                }
                .padding(.horizontal, tokens.space(.screenHorizontal))
                .padding(.top, tokens.space(.headerToPlate))
                // An empty pool still takes the swipe.
                .contentShape(Rectangle())
                // A lifted row's shadow fits above the first row; sideways it may reach over the margins and the next block.
                .environment(\.liftRoom, LiftRoom(top: tokens.space(.liftShadow), sides: tokens.size(.liftOverhang)))
            }
            .ignoresSafeArea(.container, edges: .bottom)
            .simultaneousGesture(daySwipe(width: geometry.size.width))
            .onChange(of: arrangement) { pager.resetPage() }
        }
    }

    /// On pages a horizontal drag moves them with the finger and, far enough, turns the page (`TodayPager`).
    private func daySwipe(width: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: rules.gestures.daySwipeMinimumDistance)
            .onChanged { pager.swipeChanged($0.translation, pageCount: pageCount, gestures: rules.gestures) }
            .onEnded { value in
                pager.swipeEnded(value.translation, predicted: value.predictedEndTranslation, containerWidth: width,
                                 pageCount: pageCount, gestures: rules.gestures, animation: tokens.animation)
            }
    }

    /// The arrows around the shown day's name; on another day, tapping the name goes back to today.
    private var dayNavigation: DayNavigation {
        DayNavigation(dayOffset: pager.dayOffset, onStep: { pager.changeDay(by: $0, width: width, duration: tokens.duration(.animation)) }) {
            pager.showToday(animation: tokens.animation)
        }
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
        .padding(.vertical, tokens.bar(.barSideInset))
        .ignoresSafeArea(.container, edges: .vertical)
        // Their glass casts a shadow over the blocks beside them.
        .zIndex(LiftLayer.beside(blocks: layout.blocks.count))
    }

    /// A group of bar buttons in the glass capsule the system draws around them upright.
    private func bubble(_ axis: Axis, @ViewBuilder _ buttons: () -> some View) -> some View {
        let layout = axis == .horizontal ? AnyLayout(HStackLayout(spacing: tokens.bar(.barButtonGap)))
            : AnyLayout(VStackLayout(spacing: tokens.bar(.barButtonGap)))
        return layout { buttons() }
            .buttonStyle(.plain)
            .foregroundStyle(tokens.color(.primaryText))
            .systemLook(.barCapsule)
    }

    /// The bar upright: the button groups at the edges, the day's name with its arrows midway between them.

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

/// Maps layout block ids to block views (unknown ids stop the app at config loading).
struct TodayBlock: View {
    let id: TodayBlockID
    let plan: DayPlan
    let handler: TaskActionHandler
    let bottomInset: CGFloat
    /// The edges under the system tab bar: upright, the bottom of a block that reaches the screen's bottom (lying sideways
    /// the app's own tab bar stands beside the blocks).
    let barEdges: Edge.Set

    var body: some View {
        switch id {
        case .pool: PoolBlock(plan: plan, handler: handler, bottomInset: bottomInset, barEdges: barEdges)
        case .timeline: TimelineBlock(plan: plan, handler: handler, bottomInset: bottomInset, barEdges: barEdges)
        }
    }
}
