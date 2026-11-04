import SwiftUI

/// Main screen: blocks from the arrangement's layout (`layouts/today-*.layout.json`), refreshed every
/// minute so "now" and chains move. The pool and the timeline both pull to refresh (full sync).
/// Top left: Lists with the problems badge; top right: search, in the system navigation bar with the day's name
/// centred as its title (so the bar's buttons flow into a pushed page's, as on the other tabs). In landscape the same buttons stand in a column along the physical top, each where it is upright on the
/// physical screen (see `PhysicalBottom`); the layout is the landscape one from settings. The arrows next to the day's name
/// slide the pool and the timeline together to yesterday / tomorrow (and further): another day shows its own
/// events, reminders, dated tasks and habits; its name, or the Today tab, brings back today. With the paged
/// arrangement a swipe turns between the pool and the timeline pages. Left of the pool the backlog pages (Soon, then
/// Half year, then Someday) open one by one when the first page is pulled right past its edge (`TasksStrip`); a swipe
/// moves freely between the opened pages, a backlog page has its list's title in the bar, and another tab forgets them.
/// Tasks, and the tab bar's "+", are dragged between all these pages (see `TaskDragState`, owned by `RootView`). Select from a pool row's menu turns on Select mode
/// (`PoolSelection`): the bar's buttons give way to Cancel and the actions on the picked tasks (`SelectionToolbar`).
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
    @Environment(TaskDragState.self) private var taskDrag
    @State private var selection = PoolSelection()
    @State private var isNamingSection = false
    @State private var sectionTitle = ""
    /// Where the bar's buttons stand upright (`DayBarRoom`).
    @State private var barButtons: [TodayButtons.Item: CGRect] = [:]

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
                ToolbarItemGroup(placement: .topBarLeading) {
                    if selection.isOn { selectionBar(.leading) } else { TodayButtons(placement: .leading, onFrame: barButtonMoved) }
                }
                // As wide as the bar leaves between its button groups: the name shrinks into that room rather than the
                // arrows reaching under the buttons beside them.
                ToolbarItem(placement: .principal) {
                    if selection.isOn { selectionTitle } else if let room = dayBarRoom { title.frame(width: room) } else { title }
                }
                ToolbarItemGroup(placement: .topBarTrailing) {
                    if selection.isOn { selectionBar(.trailing) } else { TodayButtons(placement: .trailing, onFrame: barButtonMoved) }
                }
            }
        }
        .actionConfirmation($pendingAction) { handler.run($0.action, taskName: $0.taskName) }
        .environment(selection)
        .alert("section.new.title", isPresented: $isNamingSection) {
            TextField("section.new.placeholder", text: $sectionTitle)
                .accessibilityIdentifier("section.new.name")
            Button("section.new.create") {
                model.newSection(titled: sectionTitle, withSelected: selection.names, on: shownDay)
                selection.end()
            }
            Button("common.cancel", role: .cancel) {}
        }
        // Another day or another tab leaves Select mode.
        .onChange(of: pager.dayOffset) { selection.end() }
        // A drag asks for a page; the pages shown now turn to it.
        .onChange(of: taskDrag.turnRequest) { _, page in
            guard let page else { return }
            if let index = TasksPageStrip.index(of: page, in: pages) { turn(to: index) }
            taskDrag.turnHandled()
        }
        .onChange(of: router.tasksTaps) { showTodaysPool(forgetsBacklog: true) }
        // Another tab forgets the backlog pages.
        .onChange(of: router.tab) { _, tab in
            if tab != .today { pager.closeBacklog(poolBlock: poolBlock) }
            selection.end()
        }
    }

    /// Turned sideways, Today has its own arrangement.
    private var arrangement: AppSettings.TodayArrangement {
        isLandscape ? model.settings.today.landscapeArrangement : model.settings.today.arrangement
    }

    private func barButtonMoved(_ item: TodayButtons.Item, to frame: CGRect?) {
        if barButtons[item] != frame { barButtons[item] = frame }
    }

    private var dayBarRoom: CGFloat? {
        let frames = { (placement: TodayButtons.Placement) in placement.items.compactMap { barButtons[$0] } }
        return DayBarRoom.width(leading: frames(.leading), trailing: frames(.trailing), gap: tokens.bar(.barButtonPadding),
                                center: width / 2)
    }

    private var layout: ScreenLayout { model.config.todayLayout(for: arrangement, landscape: isLandscape) }
    private var pages: [TasksPage] {
        TasksPageStrip.pages(layout: layout, opened: pager.openedBacklog, backlog: model.backlogLists)
    }
    private var pageCount: Int { pages.count }
    /// The pool's place among the day's pages.
    private var poolBlock: Int { TasksPageStrip.homeIndex(layout: layout, opened: 0) }

    /// The day's name: back to today and, on pages, to the pool's page; the Tasks tab also forgets the backlog pages.
    private func showTodaysPool(forgetsBacklog: Bool = false) {
        pager.showPool(poolBlock: poolBlock, forgetsBacklog: forgetsBacklog, animation: tokens.animation)
    }

    /// On a backlog page its list's title, plainly; on the day's pages the day's name with its arrows. Both always stand
    /// in the same place and change the one way titles change (`titleSwap`), whatever moves the pages.
    private var title: some View {
        let shown = pages.indices.contains(pager.page) ? pages[pager.page] : nil
        let list = shown?.backlogID.flatMap(model.config.lists.backlogList)
        let fade = Animation.easeInOut(duration: tokens.duration(.titleSwap))
        return ZStack {
            dayNavigation
                .opacity(list == nil ? 1 : 0)
                .animation(fade, value: list == nil)
                .allowsHitTesting(list == nil)
            Text(LocalizedStringKey(list?.title ?? ""))
                .font(tokens.font(.navTitle))
                .lineLimit(1)
                .minimumScaleFactor(isLandscape ? 1 : tokens.size(.navTitleMin) / tokens.uiFont(.navTitle).pointSize)
                .accessibilityAddTraits(.isHeader)
                .accessibilityIdentifier("today.listTitle")
                .titleSwap(list?.id)
                .opacity(list == nil ? 0 : 1)
                .animation(fade, value: list == nil)
                .allowsHitTesting(false)
        }
        .transaction { $0.animation = nil }
    }

    /// The day the pool shows.
    private var shownDay: LocalDate { model.context().today.adding(days: pager.dayOffset) }

    private var selectionTitle: some View {
        Text(verbatim: L10n.format("select.count", selection.names.count))
            .font(tokens.font(.navTitle))
            .lineLimit(1)
            .accessibilityAddTraits(.isHeader)
            .accessibilityIdentifier("select.title")
    }

    private func selectionBar(_ placement: SelectionToolbar.Placement, bottom: HorizontalEdge? = nil) -> SelectionToolbar {
        SelectionToolbar(placement: placement, selection: selection, day: shownDay, bottom: bottom, perform: performOnSelection)
    }

    /// An action of the selection bar: New section asks for its title first; the others act on the picked tasks at once.
    private func performOnSelection(_ action: ActionDefinition) {
        guard action.id != .newSection else {
            sectionTitle = ""
            isNamingSection = true
            return
        }
        let names = selection.names
        let day = shownDay
        selection.end()
        Task { await model.perform(action, onSelected: names, on: day) }
    }

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
                TasksStrip(layout: layout, pages: pages, pager: pager, plan: plan, handler: handler, bottomInset: bottomInset,
                           isLandscape: isLandscape, edgeInset: tokens.space(.screenHorizontal), fade: fade, onTurn: turn)
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

    /// A horizontal drag moves the pages with the finger and, far enough, turns the page; at the first page it pulls the
    /// next backlog page open (`TodayPager`).
    private func daySwipe(width: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: rules.gestures.daySwipeMinimumDistance)
            .onChanged { value in
                // A task being dragged moves itself, not the pages: they turn only by its reaching an edge.
                guard taskDrag.item == nil else { return pager.cancelSwipe() }
                let armed = pager.swipeChanged(value.translation, containerWidth: width, pageCount: pageCount,
                                               backlogCount: model.backlogLists.count, gestures: rules.gestures)
                if armed { Haptics.play(.pullArmed) }
            }
            .onEnded { value in
                // The swipe follows a dragged task's finger too: lifted with no drop, the drag ends.
                Task { await taskDrag.fingerLifted(settling: rules.gestures.dragEndSettleSeconds) }
                guard taskDrag.item == nil else { return pager.cancelSwipe() }
                pager.swipeEnded(value.translation, predicted: value.predictedEndTranslation, velocity: value.velocity,
                                 containerWidth: width, pageCount: pageCount, backlogCount: model.backlogLists.count,
                                 gestures: rules.gestures, duration: tokens.duration(.animation))
            }
    }

    /// The arrows around the shown day's name; on another day, tapping the name goes back to today.
    private var dayNavigation: DayNavigation {
        DayNavigation(dayOffset: pager.dayOffset, onStep: { pager.changeDay(by: $0, width: width, duration: tokens.duration(.animation)) }) {
            showTodaysPool()
        }
    }

    /// The phone lying sideways: the bar's buttons in a column along the physical top, each where it is on the
    /// physical screen upright (the right end of the bar at the physical right, the arrows pointing the same way).
    private func landscapeColumn(bottom: HorizontalEdge) -> some View {
        VStack(spacing: tokens.space(.groupGap)) {
            ForEach(PhysicalBottom.physicalOrder(LandscapeSlot.allCases, bottom: bottom), id: \.self) { slot in
                switch slot {
                case .leading: bubble(.vertical) {
                    if selection.isOn { selectionBar(.leading, bottom: bottom) } else { TodayButtons(placement: .leading, bottom: bottom) }
                }
                case .day: Spacer(minLength: 0); if selection.isOn { selectionTitle } else { title }; Spacer(minLength: 0)
                case .trailing: bubble(.vertical) {
                    if selection.isOn { selectionBar(.trailing, bottom: bottom) } else { TodayButtons(placement: .trailing, bottom: bottom) }
                }
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

    /// The bar upright, from the physical left to the physical right.
    private enum LandscapeSlot: CaseIterable { case leading, day, trailing }

    private var handler: TaskActionHandler {
        var handler = TaskActionHandler(model: model, router: router, openURL: openURL) { pendingAction = $0 }
        handler.shownDay = shownDay
        handler.startSelection = { name in withAnimation(tokens.animation) { selection.start(with: name) } }
        return handler
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
