import XCTest

extension XCUIApplication {
    /// Banners sit over the navigation bar for a few seconds; swipe them away like a user would.
    func dismissBanners(file: StaticString = #filePath, line: UInt = #line) {
        for _ in 0..<3 {
            let banner = descendants(matching: .any)["banner"]
            guard banner.waitForExistence(timeout: 2) else { return }
            banner.swipeUp()
            XCTAssertTrue(banner.waitForNonExistence(timeout: 3), "a swipe up must dismiss the banner", file: file, line: line)
        }
    }
}
