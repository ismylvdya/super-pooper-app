import SwiftUI

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
