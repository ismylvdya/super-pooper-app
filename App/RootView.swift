import SwiftUI

/// Top-level navigation: onboarding, then Today with pushed pages and sheets; the banner overlay
/// sits above everything.
struct RootView: View {
    let container: AppContainer
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.openURL) private var openURL
    @State private var screenHeight = BundledConfig.tokens.size(.screenHeightEstimate)

    var body: some View {
        @Bindable var router = container.router
        let model = container.model
        Group {
            if model.settings.onboarding.completed {
                TabView(selection: Binding(get: { router.tab }, set: { router.select($0) })) {
                    ForEach(AppTab.allCases, id: \.self) { tab in
                        NavigationStack(path: Binding(get: { router.paths[tab] ?? [] }, set: { router.paths[tab] = $0 })) {
                            root(tab, model: model)
                                .navigationDestination(for: Route.self) { route in
                                    destination(route).refreshable { await model.sync(announce: true) }
                                }
                        }
                        .tabItem { Label(LocalizedStringKey(String("tab.") + tab.rawValue), systemImage: container.config.icons[tab.icon]) }
                        .tag(tab)
                    }
                }
                // The banner sits right under the status bar, over the bar buttons, on every tab.
                .overlay(alignment: .top) { BannerOverlay() }
                .sheet(isPresented: $router.isReviewPresented) { MorningReviewScreen().tint(tokens.color(.accent)) }
                .sheet(isPresented: $router.isProblemsPresented) { ProblemsSheet().tint(tokens.color(.accent)) }
            } else {
                OnboardingFlow()
            }
        }
        .tint(tokens.color(.accent))
        .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { screenHeight = $0 }
        .environment(\.screenHeight, screenHeight)
        .environment(\.timelineBell, model.settings.timeline.bellStyle)
        .environment(\.calendar, model.calendar)
        // The user's colors and opacity sit closest to the views, over the bundled tokens of `appConfig`.
        .environment(\.tokens, tokens)
        .environment(model)
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
            default:
                break
            }
        }
        .onOpenURL { container.router.handle($0) }
        .onChange(of: container.router.inboxRequests) { runInboxShortcut() }
    }

    /// 📥 New in inbox: the user's shortcut (Settings → Today → Quick actions); without one, that setting opens.
    private func runInboxShortcut() {
        let name = container.model.settings.quickActions.inboxShortcut.trimmingCharacters(in: .whitespaces)
        if !name.isEmpty, let url = container.config.rules.eventLinks.shortcutURL(named: name) {
            openURL(url)
        } else {
            container.router.show(.settings, [.taskSettings])
            container.banners.show(L10n.string("banner.inboxShortcutMissing"), style: .warning)
        }
    }

    @ViewBuilder private func root(_ tab: AppTab, model: AppModel) -> some View {
        switch tab {
        case .today: home(model)
        case .habits: HabitsScreen()
        case .lists: ListsScreen()
        case .settings: SettingsScreen()
        }
    }

    /// Reading `vaultState` keeps this view observing it, so choosing a vault switches to Today.
    /// Bundled tokens with the user's color choices.
    private var tokens: DesignTokens { container.config.tokens.applying(container.model.settings, limits: container.config.rules.limits) }

    @ViewBuilder private func home(_ model: AppModel) -> some View {
        switch model.vaultState {
        case .failed(let message):
            NoVaultScreen(message: message)
        case .notSelected where !model.hasVault:
            NoVaultScreen(message: nil)
        default:
            TodayScreen()
        }
    }

    @ViewBuilder private func destination(_ route: Route) -> some View {
        switch route {
        case .task(let name): TaskPageScreen(taskName: name)
        case .newTask: NewNoteScreen(kind: .task)
        case .newHabit: NewNoteScreen(kind: .habit)
        case .search(let scope): SearchScreen(scope: scope)
        case .taskSettings: TaskSettingsScreen()
        case .habitSettings: HabitSettingsScreen()
        case .archive: ArchiveScreen()
        case .trash: TrashScreen()
        case .routines: RoutinesScreen()
        case .poolOrder: PoolOrderScreen()
        case .conflicts: ConflictsScreen()
        case .conflict(let name): ConflictVersionsScreen(noteName: name)
        case .list(let id): TaskListScreen(listID: id)
        #if DEBUG
        case .debugNotifications: NotificationsDebugScreen()
        case .debugWidgets: WidgetGalleryScreen()
        #endif
        }
    }

    /// The morning review opens by itself on the first launch of the day.
    private func openReviewIfNeeded() {
        let model = container.model
        guard model.config.flags.morningReviewAutoOpen, model.settings.onboarding.completed,
              model.vaultState == .ready, !model.dayState.reviewShown,
              container.launch.openURL == nil else { return }
        model.updateDayState { $0.reviewShown = true }
        container.router.isReviewPresented = true
    }
}

extension AppTab {
    var icon: Icon {
        switch self {
        case .today: .tabToday
        case .habits: .tabHabits
        case .lists: .tabLists
        case .settings: .tabSettings
        }
    }
}
