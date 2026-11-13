import SwiftUI

/// Top-level navigation: onboarding, then Today with pushed pages and sheets; the banner overlay
/// sits above everything. Lying sideways, the tab bar is a column along the physical bottom.
struct RootView: View {
    let container: AppContainer
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.openURL) private var openURL
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    @Environment(\.displayScale) private var displayScale
    /// Which side the physical bottom took the last time the phone lay sideways.
    @State private var landscapeBottom: HorizontalEdge = .trailing
    /// What is being dragged on Tasks: a task, a section or the tab bar's "+", which stands outside the tabs.
    @State private var taskDrag = TaskDragState()
    /// The keyboard is up: lying sideways the app's own tab bar makes room for it (the system's upright does so itself).
    @State private var isKeyboardUp = false
    /// The window's safe area: the tabs stand inside it whatever the root ignores.
    @State private var safeArea = EdgeInsets()

    private var physicalBottom: HorizontalEdge? { verticalSizeClass == .compact ? landscapeBottom : nil }

    /// The screen edge the landscape tab bar stands at (none upright).
    private var landscapeTabBarEdge: Edge.Set {
        if isKeyboardUp { return [] }
        return switch physicalBottom {
        case .leading: .leading
        case .trailing: .trailing
        case nil: []
        }
    }

    var body: some View {
        @Bindable var router = container.router
        let model = container.model
        Group {
            if model.settings.onboarding.completed {
                    TabView(selection: Binding(get: { TabBarItem.tab(router.tab) }, set: { selectTabBarItem($0, router: router) })) {
                        ForEach(AppTab.allCases, id: \.self) { tab in
                            Tab(value: TabBarItem.tab(tab)) {
                                NavigationStack(path: Binding(get: { router.paths[tab] ?? [] }, set: { router.paths[tab] = $0 })) {
                                    root(tab, model: model)
                                        .systemTabBar(isShown: physicalBottom == nil)
                                        .navigationDestination(for: Route.self) { route in
                                            destination(route, in: tab)
                                                .syncsOnPull()
                                                .systemTabBar(isShown: physicalBottom == nil)
                                        }
                                }
                                .padding(landscapeEdge, landscapeRoom(of: tab))
                                // The room is the screen's own background, as on Tasks: no bar of the tab view's shows through it.
                                .screenBackground()
                                // The tab bar's own color stops at the bar.
                                .tint(tokens.color(.accent))
                            } label: {
                                Label {
                                    Text(LocalizedStringKey(String("tab.") + tab.rawValue))
                                } icon: {
                                    TabIconImage.image(model.tabBarSymbols.symbol(of: tab, isSelected: false),
                                                       font: tokens.uiFont(.systemTabIcon),
                                                       others: container.config.icons.otherTabSymbols(than: tab),
                                                       fit: tokens.bar(.tabGlyphFit), scale: displayScale)
                                        // The symbol as named: the bar's own variant would fill every tab. The current tab's filled one
                                        // is the item's selected image (`TabBarSelectedSymbols`).
                                        .environment(\.symbolVariants, .none)
                                }
                            }
                        }
                        // The "+": iOS 26 draws a search-role tab apart, on the right; `NewItemButton` takes the touches over it.
                        Tab(value: TabBarItem.newItem, role: .search) {
                            Color.clear
                        } label: {
                            Label { Text("newItem.title") } icon: { Image(systemName: model.tabBarSymbols.newItem) }
                        }
                    }
                    .tint(tokens.color(.tabBar))
                    .overlay { if physicalBottom == nil { uprightNewItemButton } }
                    // The bar draws each item's selected image itself, under its moving drop.
                    .background { TabBarSelectedSymbols(symbols: AppTab.allCases.map { model.tabBarSymbols.symbol(of: $0, isSelected: true) }) { name in
                        TabIconImage.glyph(name, font: tokens.uiFont(.systemTabIcon), others: container.config.icons.otherTabSymbols(than: router.tab),
                                           fit: tokens.bar(.tabGlyphFit), scale: displayScale)
                    } }
                // Lying sideways the app's own tab bar floats over the tabs' edge. Its inner side is the screen's edge for the pages
                // (`landscapeRoom`); Today's strip keeps that room itself, so what it pushes past shows through the glass.
                .overlay(alignment: physicalBottom == .leading ? .leading : .trailing) {
                    if let physicalBottom, !isKeyboardUp { LandscapeTabBar(bottom: physicalBottom) }
                }
                // The landscape tab bar is laid out from the screen edge at the physical bottom, not from the safe area,
                // so no empty strip is left between it and the tabs.
                .ignoresSafeArea(.container, edges: landscapeTabBarEdge)
                // Behind the tabs and the landscape tab bar.
                .screenBackground()
                // The banner sits over the navigation bar, its corners on the bar buttons, on every tab.
                .overlay(alignment: .top) { BannerOverlay(yieldsToSheets: true) }
                .overlay { NewItemDragOverlay() }
                .sheet(isPresented: $router.isReviewPresented) {
                    MorningReviewScreen().tint(tokens.color(.accent)).presentationDragIndicator(.visible)
                }
                .sheet(isPresented: $router.isProblemsPresented) { ProblemsSheet().tint(tokens.color(.accent)) }
            } else {
                OnboardingFlow()
            }
        }
        .tint(tokens.color(.accent))
        .onGeometryChange(for: EdgeInsets.self) { $0.safeAreaInsets } action: { safeArea = $0 }
        .onGeometryChange(for: CGSize.self) { $0.size } action: { _ in updateLandscapeBottom() }
        .onReceive(NotificationCenter.default.publisher(for: UIDevice.orientationDidChangeNotification)) { _ in updateLandscapeBottom() }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { _ in isKeyboardUp = true }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in isKeyboardUp = false }
        .environment(\.physicalBottom, physicalBottom)
        .environment(\.timelineBell, model.settings.timeline.bellStyle)
        .environment(\.chipOrder, RowChipKind.ordered(model.settings.pool.chipOrder))
        .environment(\.highPriorityLook, model.settings.pool.highPriorityLook)
        .environment(\.subtaskLineLook, SubtaskLineLook(corner: model.settings.pool.subtaskLineCorner,
                                                       roundsMiddle: model.settings.pool.subtaskLineRoundsMiddle))
        .environment(\.startedLayout, StartedLayout(look: model.settings.pool.startedLook, fillLength: model.settings.pool.startedFillLength,
                                                    titleAfterFill: model.settings.pool.startedTitleAfterFill,
                                                    circleSize: model.settings.pool.startedCircleSize,
                                                    fadeMiddle: model.settings.pool.startedFadeMiddle,
                                                    fadeWidth: model.settings.pool.startedFadeWidth,
                                                    titleGap: model.settings.pool.startedTitleGap))
        .appCalendar(model.calendar)
        // The user's colors and opacity sit closest to the views, over the bundled tokens of `appConfig`.
        .designTokens(tokens)
        .environment(\.rules, container.config.rules.withEstimates(model.settings.pool.estimateMinutes))
        .environment(model)
        .environment(taskDrag)
        .environment(container.router)
        .environment(container.banners)
        .appConfig(container.config)
        .task {
            await container.start()
            openReviewIfNeeded()
        }
        .onChange(of: scenePhase) { _, phase in
            switch phase {
            case .active where model.hasLoaded:
                Task {
                    await model.sync(announce: false)
                    openReviewIfNeeded()
                }
            case .background:
                BackgroundRefresh.schedule()
                Task {
                    await BackgroundTime.finish("leave") {
                        await model.flushTexts()
                        await model.flushSettings()
                    }
                }
            default:
                break
            }
        }
        // Waits again when the day turns or its end moves (a new time zone).
        .task(id: model.context().dayEnd) { await model.syncWhenTheDayEnds() }
        .onOpenURL { container.router.handle($0) }
    }


    /// The "+" over the room the system tab bar keeps for it, under the keyboard rather than above it. Read within the
    /// safe area (its insets are lost once a view ignores it) and laid out in screen coordinates.
    private var uprightNewItemButton: some View {
        GeometryReader { geometry in
            let insets = geometry.safeAreaInsets
            let screen = CGSize(width: geometry.size.width + insets.leading + insets.trailing,
                                height: geometry.size.height + insets.top + insets.bottom)
            let frame = SystemLook.newItemSlot(tokens: tokens, tabCount: AppTab.allCases.count + 1)
                .frame(in: screen, bottomSafeArea: insets.bottom)
            NewItemButton(drawsBubble: false)
                .frame(width: frame.width, height: frame.height)
                .position(x: frame.midX - insets.leading, y: frame.midY - insets.top)
        }
        .ignoresSafeArea(.keyboard)
    }

    @ViewBuilder private func root(_ tab: AppTab, model: AppModel) -> some View {
        switch tab {
        case .today: home(model)
        case .habits: HabitsScreen()
        case .settings: SettingsScreen()
        }
    }

    private var landscapeEdge: Edge.Set { physicalBottom == .leading ? .leading : .trailing }

    /// The room a tab's stack keeps from the landscape tab bar. It stands inside the safe area, so that part of the room is
    /// there already. Tasks' first page has no system bar and keeps the room itself.
    private func landscapeRoom(of tab: AppTab) -> CGFloat {
        guard let physicalBottom, !isKeyboardUp else { return 0 }
        if tab == .today, (container.router.paths[tab] ?? []).isEmpty { return 0 }
        return max(tokens.bar(.landscapeTabBarRoom) - (physicalBottom == .leading ? safeArea.leading : safeArea.trailing), 0)
    }

    /// The "+"'s slot chosen on the system bar: the bar first goes back to its tab, then the page opens on it; opened at
    /// once, the tab's stack would be taken down and put up again under it.
    private func selectTabBarItem(_ item: TabBarItem, router: Router) {
        guard item == .newItem else { return TabBarItem.selection(item, router: router) }
        DispatchQueue.main.async { TabBarItem.selection(item, router: router) }
    }

    /// The window's orientation when it already turned, else the phone's (lying flat keeps the last side).
    private func updateLandscapeBottom() {
        let window = UIApplication.shared.connectedScenes.lazy.compactMap { $0 as? UIWindowScene }.first?.effectiveGeometry.interfaceOrientation
        if let edge = window.flatMap(PhysicalBottom.edge(for:)) ?? PhysicalBottom.edge(for: UIDevice.current.orientation) {
            landscapeBottom = edge
        }
    }

    /// Reading `vaultState` keeps this view observing it, so choosing a vault switches to Today.
    /// Bundled tokens with the user's color choices.
    private var tokens: DesignTokens { container.config.tokens.applying(container.model.settings, limits: container.config.rules.limits) }

    @ViewBuilder private func home(_ model: AppModel) -> some View {
        switch model.vaultState {
        case .failed(let failure):
            NoVaultScreen(failure: failure)
        case .notSelected where !model.hasVault:
            NoVaultScreen(failure: nil)
        default:
            TodayScreen()
        }
    }

    @ViewBuilder private func destination(_ route: Route, in tab: AppTab) -> some View {
        switch route {
        case .task(let name): TaskPageScreen(taskName: name)
        case .newItem(let seed): NewItemScreen(seed: seed, tab: tab)
        case .lists: ListsScreen()
        case .search(let scope): SearchPage(scope: scope)
        case .taskSettings: TaskSettingsScreen()
        case .clockSettings: ClockSettingsScreen()
        case .tabBarSettings: TabBarSettingsScreen()
        case .plainTaskSettings: PlainTaskSettingsScreen()
        case .generalSettings: GeneralSettingsScreen()
        case .notificationSettings: NotificationSettingsScreen()
        case .widgetSettings: WidgetSettingsScreen()
        case .habitSettings: HabitSettingsScreen()
        case .archive: ArchiveScreen()
        case .trash: TrashScreen()
        case .routines: RoutinesScreen()
        case .poolOrder: PoolOrderScreen()
        case .chipOrder: ChipOrderScreen()
        case .conflicts: ConflictsScreen()
        case .conflict(let name): ConflictVersionsScreen(noteName: name)
        case .list(let id): TaskListScreen(listID: id)
        case .morningReview: MorningReviewPage()
        #if DEBUG
        case .debugNotifications: NotificationsDebugScreen()
        case .debugWidgets: WidgetGalleryScreen()
        #endif
        }
    }

    /// The morning review opens by itself on the first launch of the day.
    private func openReviewIfNeeded() {
        if container.model.claimMorningReview(openedForSomethingElse: container.launch.openURL != nil) {
            container.router.isReviewPresented = true
        }
    }
}

extension AppTab {
    var icon: Icon {
        switch self {
        case .today: .tabToday
        case .habits: .tabHabits
        case .settings: .tabSettings
        }
    }
}

extension IconSet {
    /// The symbols of the tabs beside `tab`: a hand-drawn tab glyph stands within them.
    func otherTabSymbols(than tab: AppTab) -> [String] {
        AppTab.allCases.filter { $0 != tab }.map { self[$0.icon] }
    }
}

private extension View {
    /// Lying sideways the app draws its own tab bar along the physical bottom instead of the system one.
    func systemTabBar(isShown: Bool) -> some View {
        toolbar(isShown ? .visible : .hidden, for: .tabBar)
    }
}
