import SwiftUI

/// Top-level navigation: onboarding, then Today with pushed pages and sheets; the banner overlay
/// sits above everything.
struct RootView: View {
    let container: AppContainer
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        @Bindable var router = container.router
        let model = container.model
        Group {
            if model.settings.onboarding.completed {
                NavigationStack(path: $router.path) {
                    home(model)
                        .bannerHost()
                        .navigationDestination(for: Route.self) { destination($0).bannerHost() }
                }
                .sheet(isPresented: $router.isReviewPresented) { MorningReviewScreen() }
                .sheet(isPresented: $router.isProblemsPresented) { ProblemsSheet() }
                .refreshable { await model.sync(announce: true) }
            } else {
                OnboardingFlow()
            }
        }
        .tint(container.config.tokens.color(.accent))
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
    }

    /// Reading `vaultState` keeps this view observing it, so choosing a vault switches to Today.
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
        case .settings: SettingsScreen()
        case .archive: ArchiveScreen()
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

extension View {
    /// Shows the banner at the top of this page's content (below the navigation bar, so it
    /// never covers bar buttons). Every page and sheet hosts it; the same banner dismisses once.
    func bannerHost() -> some View {
        overlay(alignment: .top) { BannerOverlay() }
    }
}

/// Renders the current banner from the banner center.
struct BannerOverlay: View {
    @Environment(BannerCenter.self) private var banners
    @Environment(\.tokens) private var tokens

    var body: some View {
        ZStack {
            if let banner = banners.current {
                BannerView(text: banner.text, icon: icon(banner.style), tint: tint(banner.style)) {
                    withAnimation(.easeInOut(duration: tokens.duration(.bannerAnimation))) { banners.dismiss(banner.id) }
                }
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
        case .problem: .problem
        }
    }

    private func tint(_ style: BannerCenter.Banner.Style) -> Color {
        switch style {
        case .info: tokens.color(.accent)
        case .synced, .success: tokens.color(.pleasant)
        case .problem: tokens.color(.problem)
        }
    }
}

/// Without a vault (or when it can't be opened) the app explains itself and offers the picker.
struct NoVaultScreen: View {
    let message: String?
    @State private var isPickerPresented = false

    var body: some View {
        EmptyStateView(icon: .emptyVault, title: message == nil ? "vault.empty.title" : "vault.error.title",
                       message: message.map { LocalizedStringKey($0) } ?? "vault.empty.message",
                       actionTitle: "vault.choose") { isPickerPresented = true }
            .vaultPicker(isPresented: $isPickerPresented)
    }
}
