import CoreGraphics
import Testing
@testable import SuperPooperApp

/// The banner stands over the navigation bar, concentric with its round buttons: its corner is the button's circle.
struct BannerPlacementTests {
    @Test func theCornerLiesOnTheButtonsCircle() {
        let placement = BannerPlacement(bar: 54, button: 42, sideInset: 16)
        #expect(placement.radius == 21)
        #expect(placement.height == 42, "collapsed, as tall as a bar button: it covers the bar's row and no more")
        #expect(placement.top == 6, "as high as the buttons, which stand in the middle of the bar")
        #expect(placement.side == 16)
        // The centre of the banner's top-left corner is the centre of the leading button.
        let buttonCenter = CGPoint(x: 16 + 21, y: 6 + 21)
        #expect(placement.side + placement.radius == buttonCenter.x)
        #expect(placement.top + placement.radius == buttonCenter.y)
    }

    @Test func theAppsBannerComesFromTheBarMetrics() {
        let tokens = TestConfig.tokens
        #expect(tokens.bannerPlacement == BannerPlacement(bar: tokens.bar(.navigationBar), button: tokens.bar(.barButton),
                                                          sideInset: tokens.bar(.barSideInset)))
    }
}
