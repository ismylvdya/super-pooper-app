import CoreGraphics
import Testing
@testable import SuperPooperApp

/// The tab bar's "+" slot and where the app's own "+" stands over it.
@MainActor
struct TabBarItemTests {
    @Test func theReservedSlotOpensTheNewItemPageAndKeepsTheTab() {
        let router = Router()
        router.select(.habits)
        TabBarItem.selection(.newItem, router: router)
        #expect(router.tab == .habits && router.path == [.newItem(NewItemSeed(kind: .habit))])
    }

    @Test func aTabIsSelectedAsBefore() {
        let router = Router()
        TabBarItem.selection(.tab(.settings), router: router)
        #expect(router.tab == .settings)
    }

    /// iOS 18: the last of the equal tab items, standing on the safe area's bottom.
    @Test func onTheClassicBarThePlusTakesTheLastItem() {
        let frame = NewItemSlot.lastTab(count: 4, height: 49).frame(in: CGSize(width: 400, height: 800), bottomSafeArea: 34)
        #expect(frame == CGRect(x: 300, y: 717, width: 100, height: 49))
    }

    /// iOS 26: a round bubble at the trailing bottom corner, as far from both edges.
    @Test func onTheGlassBarThePlusIsARoundBubbleInTheCorner() {
        let frame = NewItemSlot.bubble(diameter: 62, inset: 21).frame(in: CGSize(width: 400, height: 800), bottomSafeArea: 34)
        #expect(frame == CGRect(x: 317, y: 717, width: 62, height: 62))
    }

    @Test func thisBuildPicksTheSlotOfItsSystemLook() {
        let slot = SystemLook.newItemSlot(tokens: TestConfig.tokens, tabCount: AppTab.allCases.count + 1)
        #expect(slot == .lastTab(count: 4, height: TestConfig.tokens.bar(.classicTabBar))
                || slot == .bubble(diameter: TestConfig.tokens.bar(.newItemBubble), inset: TestConfig.tokens.bar(.newItemBubbleInset)))
    }
}
