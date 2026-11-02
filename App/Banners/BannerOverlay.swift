import SwiftUI

extension View {
    /// Shows the banner over the navigation bar of this view, which holds the bar (a sheet's navigation stack; the tabs'
    /// one host is the root view's): its corners on the bar's round buttons (`BannerPlacement`). The same banner
    /// dismisses once. Pages of a tab show it only while their tab is selected (all tabs stay alive in the tab view).
    func bannerHost(tab: AppTab? = nil) -> some View {
        overlay(alignment: .top) { BannerOverlay(tab: tab) }
    }
}

/// Renders the current banner from the banner center.
struct BannerOverlay: View {
    @Environment(BannerCenter.self) private var banners
    @Environment(Router.self) private var router
    @Environment(AppModel.self) private var model
    @Environment(\.rules) private var rules
    var tab: AppTab?
    /// The tabs' host: while a sheet shows the banner on its own bar, this one would lie under the sheet, where a swipe
    /// meant for it moves the sheet instead.
    var yieldsToSheets = false
    @Environment(\.tokens) private var tokens

    var body: some View {
        ZStack {
            if let banner = banners.current, tab == nil || tab == router.tab, !(yieldsToSheets && router.presentsBannerSheet) {
                BannerView(text: banner.text, icon: icon(banner.style), tint: tint(banner.style), counts: banner.counts,
                           items: banner.items,
                           hidesAfter: banner.undo == nil ? rules.banners.autoHideSeconds : rules.banners.undoSeconds,
                           onDismiss: {
                    withAnimation(.easeInOut(duration: tokens.duration(.bannerAnimation))) { banners.dismiss(banner.id) }
                }, onTap: banner.opens.map { target in { router.show(target.tab, target.routes) } },
                           onUndo: banner.undo.map { id in { Task { await model.undo(id) } } })
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
