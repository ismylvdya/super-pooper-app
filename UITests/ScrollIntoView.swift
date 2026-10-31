import XCTest

extension XCUIApplication {
    /// Scrolls a long list until `element` stands well inside the window. A lazy list already has the rows just below
    /// the screen's edge, so existing is not enough: a tap there would land under the home indicator. The size of the
    /// screen decides how far that is, so the tests do not count swipes. After a swipe the list still glides; a tap
    /// then only stops it, so the element is checked once it stands still.
    func scrollIntoView(_ element: XCUIElement, file: StaticString = #filePath, line: UInt = #line) {
        let window = windows.firstMatch.frame
        let reachable = window.insetBy(dx: 0, dy: window.height / 8)
        for _ in 0..<8 {
            settle(element)
            if element.exists, reachable.contains(CGPoint(x: element.frame.midX, y: element.frame.midY)) { return }
            if element.exists, element.frame.midY < reachable.minY { swipeDown() } else { swipeUp() }
        }
        XCTFail("\(element) never came into view", file: file, line: line)
    }

    /// Waits until the element's place stops changing (a list gliding after a swipe), a few seconds at most.
    private func settle(_ element: XCUIElement) {
        var last = element.exists ? element.frame : .null
        for _ in 0..<10 {
            Thread.sleep(forTimeInterval: 0.3)
            let now = element.exists ? element.frame : .null
            if now == last { return }
            last = now
        }
    }
}
