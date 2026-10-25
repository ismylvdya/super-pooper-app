import XCTest

extension XCUIApplication {
    /// Banners sit over the navigation bar for a few seconds; swipe them away like a user would. Banners come
    /// one after another, so each swiped banner is waited for by its text: the next one may already be showing.
    func dismissBanners(file: StaticString = #filePath, line: UInt = #line) {
        for _ in 0..<3 {
            // A sheet has a banner host of its own: the same banner can be found twice.
            let banner = descendants(matching: .any).matching(identifier: "banner").firstMatch
            guard banner.waitForExistence(timeout: 2) else { return }
            let swiped = descendants(matching: .any)
                .matching(NSPredicate(format: "identifier == 'banner' AND label == %@", banner.label)).firstMatch
            banner.swipeUp()
            XCTAssertTrue(swiped.waitForNonExistence(timeout: 3), "a swipe up must dismiss the banner", file: file, line: line)
        }
    }
}
