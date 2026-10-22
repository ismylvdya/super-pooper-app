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
                        .navigationDestination(for: Route.self, destination: destination)
                }
                .sheet(isPresented: $router.isReviewPresented) { MorningReviewScreen() }
                .sheet(isPresented: $router.isProblemsPresented) { ProblemsSheet() }
            } else {
                OnboardingFlow()
            }
        }
        .tint(container.config.tokens.color(.accent))
        .overlay(alignment: .top) { BannerOverlay() }
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

    @ViewBuilder private func home(_ model: AppModel) -> some View {
        if model.services.vault.hasVault {
            TodayScreen()
        } else {
            NoVaultScreen()
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
        case .info: .sync
        case .success: .markDone
        case .problem: .problem
        }
    }

    private func tint(_ style: BannerCenter.Banner.Style) -> Color {
        switch style {
        case .info: tokens.color(.accent)
        case .success: tokens.color(.pleasant)
        case .problem: tokens.color(.problem)
        }
    }
}

/// Without a vault the app explains itself and offers the folder picker.
struct NoVaultScreen: View {
    @Environment(AppModel.self) private var model
    @State private var isPickerPresented = false

    var body: some View {
        EmptyStateView(icon: .emptyVault, title: "vault.empty.title", message: "vault.empty.message",
                       actionTitle: "vault.choose") { isPickerPresented = true }
            .vaultPicker(isPresented: $isPickerPresented)
    }
}
