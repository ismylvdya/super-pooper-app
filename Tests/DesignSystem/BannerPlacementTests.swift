import CoreGraphics
import Testing
@testable import SuperPooperApp

/// The banner stands just under the navigation bar's round buttons, as tall and as round as they are.
struct BannerPlacementTests {
    @Test func itStandsUnderTheButtonsAsFarAsTheyAreFromTheStatusBar() {
        let placement = BannerPlacement(bar: 54, button: 42, sideInset: 16, gapBelowButtons: 17)
        #expect(placement.radius == 21)
        #expect(placement.height == 42)
        let expected: CGFloat = 6 + 42 + 17 // the button's top, its height, then the gap
        #expect(placement.top == expected)
        #expect(placement.side == 16)
    }

    @Test func theAppsBannerComesFromTheBarMetrics() {
        let tokens = TestConfig.tokens
        #expect(tokens.bannerPlacement == BannerPlacement(bar: tokens.bar(.navigationBar), button: tokens.bar(.uprightBarButton),
                                                          sideInset: tokens.bar(.barSideInset), gapBelowButtons: tokens.bar(.bannerBelowButtons)))
    }
}
