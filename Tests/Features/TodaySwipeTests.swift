import Foundation
import Testing
@testable import SuperPooperApp

/// Swipes on Today: they turn the pages, never the day.
struct TodaySwipeTests {
    /// A swipe only turns the pages; past the edge it does nothing (days change with the buttons).
    @Test func onPagesASwipeTurnsThePageAndStopsAtTheEdge() {
        #expect(TodaySwipe.page(forward: true, page: 0, pageCount: 2) == 1)
        #expect(TodaySwipe.page(forward: true, page: 1, pageCount: 2) == nil)
        #expect(TodaySwipe.page(forward: false, page: 1, pageCount: 2) == 0)
        #expect(TodaySwipe.page(forward: false, page: 0, pageCount: 2) == nil)
        #expect(TodaySwipe.page(forward: true, page: 0, pageCount: 1) == nil)
    }

    /// The first movement decides the direction: a vertical scroll that later drifts sideways never turns the page.
    @Test func aDragKeepsTheDirectionOfItsFirstMovement() {
        #expect(TodaySwipe.axis(locked: nil, width: 4, height: 30, axisRatio: 1.5) == .vertical)
        #expect(TodaySwipe.axis(locked: .vertical, width: 200, height: 30, axisRatio: 1.5) == .vertical)
        #expect(TodaySwipe.axis(locked: .horizontal, width: 40, height: 90, axisRatio: 1.5) == .horizontal)
        let gestures = TestConfig.rules.gestures
        #expect(!TodaySwipe.isSwipe(axis: .vertical, width: 300, predictedWidth: 300, containerWidth: 375, gestures: gestures))
        #expect(TodaySwipe.isSwipe(axis: .horizontal, width: 120, predictedWidth: 120, containerWidth: 375, gestures: gestures))
        #expect(!TodaySwipe.isSwipe(axis: .horizontal, width: 40, predictedWidth: 150, containerWidth: 375, gestures: gestures))
        #expect(TodaySwipe.isSwipe(axis: .horizontal, width: 40, predictedWidth: 200, containerWidth: 375, gestures: gestures))
    }
}
