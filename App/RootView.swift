import SwiftUI

/// Top-level navigation: onboarding, then Today with pushed pages and sheets; the banner overlay
/// sits above everything.
struct RootView: View {
    let container: AppContainer
    @Environment(\.scenePhase) private var scenePhase
    @State private var screenHeight: CGFloat = 800

    var body: some View {
        @Bindable var router = container.router
        let model = container.model
        Group {
            if model.settings.onboarding.completed {
                TabView(selection: $router.tab) {
                    ForEach(AppTab.allCases, id: \.self) { tab in
                        NavigationStack(path: Binding(get: { router.paths[tab] ?? [] }, set: { router.paths[tab] = $0 })) {
                            root(tab, model: model)
                                .bannerHost(tab: tab)
                                .navigationDestination(for: Route.self) { route in
                                    destination(route).bannerHost(tab: tab).refreshable { await model.sync(announce: true) }
                                }
                        }
                        .tabItem { Label(LocalizedStringKey(String("tab.") + tab.rawValue), systemImage: container.config.icons[tab.icon]) }
                        .tag(tab)
                    }
                }
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
        .environment(model)
        .environment(container.router)
        .environment(container.banners)
        .appConfig(container.config)
        .environment(\.tokens, tokens)
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
    }

    @ViewBuilder private func root(_ tab: AppTab, model: AppModel) -> some View {
        switch tab {
        case .today: home(model)
        case .habits: HabitsScreen()
        case .settings: SettingsScreen()
        }
    }

    /// Reading `vaultState` keeps this view observing it, so choosing a vault switches to Today.
    /// Bundled tokens with the user's color choices.
    private var tokens: DesignTokens { container.config.tokens.applying(container.model.settings) }

    @ViewBuilder private func home(_ model: AppModel) -> some View {
        switch model.vaultState {
        case .failed(let message):
            NoVaultScreen(message: message)
        case .notSelected where !model.services.vault.hasVault:
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
        case .search: SearchScreen()
        case .taskSettings: TaskSettingsScreen()
        case .habitSettings: HabitSettingsScreen()
        case .archive: ArchiveScreen()
        case .habitArchive: HabitArchiveScreen()
        case .trash: TrashScreen()
        case .conflicts: ConflictsScreen()
        case .conflict(let name): ConflictVersionsScreen(noteName: name)
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
        case .settings: .tabSettings
        }
    }
}

extension View {
    /// Shows the banner at the top of this page's content (below the navigation bar, so it
    /// never covers bar buttons). Every page and sheet hosts it; the same banner dismisses once.
    /// Pages of a tab show it only while their tab is selected (all tabs stay alive in the tab view).
    func bannerHost(tab: AppTab? = nil) -> some View {
        overlay(alignment: .top) { BannerOverlay(tab: tab) }
    }
}

/// Renders the current banner from the banner center.
struct BannerOverlay: View {
    @Environment(BannerCenter.self) private var banners
    @Environment(Router.self) private var router
    var tab: AppTab?
    @Environment(\.tokens) private var tokens

    var body: some View {
        ZStack {
            if let banner = banners.current, tab == nil || tab == router.tab {
                BannerView(text: banner.text, icon: icon(banner.style), tint: tint(banner.style), onDismiss: {
                    withAnimation(.easeInOut(duration: tokens.duration(.bannerAnimation))) { banners.dismiss(banner.id) }
                }, onTap: banner.opens.map { route in { router.show(.settings, [route]) } })
                .id(banner.id)
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: tokens.duration(.bannerAnimation)), value: banners.current?.id)
    }

    private func icon(_ style: BannerCenter.Banner.Style) -> Icon {
        switch style {
        case .info, .synced: .sync
        case .success: .markDone
        case .warning, .problem: .problem
        }
    }

    /// Good and neutral news is green, warnings yellow, errors red; never the accent color.
    private func tint(_ style: BannerCenter.Banner.Style) -> Color {
        switch style {
        case .info, .synced, .success: tokens.color(.success)
        case .warning: tokens.color(.warning)
        case .problem: tokens.color(.error)
        }
    }
}

/// Without a vault (or when it can't be opened) the app explains itself and offers the picker.
/// DEBUG builds also offer the test vault that `sim.sh load-vault` puts into Documents.
struct NoVaultScreen: View {
    @Environment(AppModel.self) private var model
    let message: String?
    @State private var isPickerPresented = false

    var body: some View {
        VStack {
            EmptyStateView(icon: .emptyVault, title: message == nil ? "vault.empty.title" : "vault.error.title",
                           message: message.map { LocalizedStringKey($0) } ?? "vault.empty.message",
                           actionTitle: "vault.choose") { isPickerPresented = true }
            #if DEBUG
            Button("vault.useTestVault") {
                let url = URL.documentsDirectory.appendingPathComponent("TestVault", isDirectory: true)
                Task { await model.selectVault(url) }
            }
            .padding(.bottom)
            #endif
        }
        .vaultPicker(isPresented: $isPickerPresented)
    }
}
