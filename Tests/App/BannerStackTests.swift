import Foundation
import Testing
@testable import SuperPooperApp

/// Banners stack: a new one shows at once on top, and when it leaves the one under it, not gone yet, is on top again.
@MainActor
@Suite("Banner stack")
struct BannerStackTests {
    @Test func aNewBannerShowsAtOnceOverTheOthers() {
        let center = BannerCenter()
        let first = BannerCenter.Banner(text: "first")
        let second = BannerCenter.Banner(text: "second")
        center.show(first)
        center.show(second)
        #expect(center.current?.id == second.id)
        #expect(center.stack.map(\.id) == [first.id, second.id])
    }

    @Test func whenTheTopOneLeavesTheOneUnderItIsOnTop() {
        let center = BannerCenter()
        let first = BannerCenter.Banner(text: "first")
        let second = BannerCenter.Banner(text: "second")
        center.show(first)
        center.show(second)
        center.dismiss(second.id)
        #expect(center.current?.id == first.id)
        center.dismiss(first.id)
        #expect(center.current == nil)
    }

    @Test func oneUnderTheTopLeavesOnItsOwnTime() {
        let center = BannerCenter()
        let first = BannerCenter.Banner(text: "first")
        let second = BannerCenter.Banner(text: "second")
        center.show(first)
        center.show(second)
        center.dismiss(first.id)
        #expect(center.stack.map(\.id) == [second.id])
    }
}
