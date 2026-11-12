import SwiftUI

extension View {
    /// Shows the banner between the navigation bar's buttons of this view, which holds the bar (a sheet's navigation stack; the
    /// tabs' one host is the root view's; `BannerPlacement`). The same banner
    /// dismisses once. Pages of a tab show it only while their tab is selected (all tabs stay alive in the tab view).
    func bannerHost(tab: AppTab? = nil) -> some View {
        overlay(alignment: .top) { BannerOverlay(tab: tab).environment(\.bannerInSheet, true) }
    }
}

/// Renders the banner center's stack: the newest on top, a few under it peeking out below.
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
        let shown = tab == nil || tab == router.tab
        ZStack(alignment: .top) {
            if shown, !(yieldsToSheets && router.presentsBannerSheet) {
                let visible = Array(banners.stack.suffix(tokens.count(.bannerStack)))
                ForEach(Array(visible.enumerated()), id: \.element.id) { index, banner in
                    let depth = visible.count - 1 - index
                    view(of: banner)
                        .scaleEffect(1 - tokens.ratio(.bannerStackShrink) * Double(depth), anchor: .bottom)
                        .offset(y: tokens.space(.bannerStackPeek) * Double(depth))
                        .allowsHitTesting(depth == 0)
                        .zIndex(Double(index))
                        .transition(.move(edge: .top).combined(with: .opacity))
                }
            }
        }
        .animation(.easeInOut(duration: tokens.duration(.bannerAnimation)), value: banners.stack.map(\.id))
    }

    /// One banner of the stack; each hides after its own time, under the top one too.
    private func view(of banner: BannerCenter.Banner) -> some View {
        BannerView(text: banner.text, icon: icon(banner.style), tint: tint(banner.style), counts: banner.counts,
                   items: banner.items,
                   hidesAfter: banner.seconds(rules.banners),
                   onDismiss: {
            withAnimation(.easeInOut(duration: tokens.duration(.bannerAnimation))) { banners.dismiss(banner.id) }
        }, onTap: banner.opens.map { target in { router.show(target.tab, target.routes) } },
                   onUndo: banner.undo.map { id in { Task { await model.undo(id) } } })
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
        if style.isGood { return tokens.color(.success) }
        return style == .warning ? tokens.color(.warning) : tokens.color(.error)
    }
}
