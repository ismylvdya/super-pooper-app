import XCTest

extension XCUIApplication {
    /// Scrolls a long list until `element` stands well inside the window. A lazy list already has the rows just below
    /// the screen's edge, so existing is not enough: a tap there would land under the home indicator. The size of the
    /// screen decides how far that is, so the tests do not count swipes. After a swipe the list still glides; a tap
    /// then only stops it, so the element is checked once it stands still. A list scrolls under its navigation bar, and a
    /// row there still exists while the bar takes its taps: the element must stand wholly below the bars. A swipe ends a
    /// little elsewhere each time, so a row left in sight but under a bar is placed below it by a drag that does not glide.
    func scrollIntoView(_ element: XCUIElement, file: StaticString = #filePath, line: UInt = #line) {
        let window = windows.firstMatch.frame
        let bottom = window.maxY - window.height / 8
        for _ in 0..<8 {
            settle(element)
            guard element.exists else { swipeUp(); continue }
            let top = max(window.minY + window.height / 8, barsBottom(in: window))
            let frame = element.frame
            if frame.minY >= top, frame.midY <= bottom { return }
            if frame.midY >= window.minY, frame.midY <= bottom {
                place(element, topAt: (top - window.minY) / window.height + 0.1)
                continue
            }
            if frame.midY < top { swipeDown() } else { swipeUp() }
        }
        XCTFail("\(element) never came into view", file: file, line: line)
    }

    /// The lowest edge of the navigation bars in the window's top half (a sheet's own and the one of the page under it).
    private func barsBottom(in window: CGRect) -> CGFloat {
        navigationBars.allElementsBoundByIndex.map(\.frame.maxY).filter { $0 < window.midY }.max() ?? window.minY
    }

    /// Drags the list without letting it glide on until `element`'s top stands `share` of the window down, so a picture
    /// taken then shows the same part of the list in every run (after a swipe the list stops a little elsewhere each time).
    func place(_ element: XCUIElement, topAt share: CGFloat) {
        let window = windows.firstMatch.frame
        for _ in 0..<3 {
            settle(element)
            let distance = window.minY + window.height * share - element.frame.minY
            if abs(distance) < 0.5 { return }
            // In the screen's side margin, where the list itself takes the drag; from low down when it goes up.
            let start = coordinate(withNormalizedOffset: CGVector(dx: 0.03, dy: distance < 0 ? 0.85 : 0.15))
            start.press(forDuration: 0.05, thenDragTo: start.withOffset(CGVector(dx: 0, dy: distance)), withVelocity: .slow,
                        thenHoldForDuration: 0.3)
        }
        settle(element)
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
