import CoreGraphics
import Testing
@testable import SuperPooperApp

@Suite struct BannerPlacementTests {
    @Test func standsBetweenTheBarsButtons() {
        let placement = BannerPlacement(bar: 44, button: 44, sideInset: 16)
        #expect(placement.top == 0)
        #expect(placement.side == 76)
        #expect(placement.height == 44)
        #expect(placement.radius == 22)
    }

    @Test func sidewaysIsAsFarFromTheTopAsFromTheSides() {
        #expect(BannerPlacement(bar: 44, button: 44, sideInset: 16).sidewaysTop == 16)
    }
}
