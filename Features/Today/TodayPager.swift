import SwiftUI

/// Where Today stands: the page of a paged layout and how far a finger has moved it, the day shown and how far it has
/// slid out. The screen draws from it; the swipe, the page edge, a dragged task, the arrows and the Today tab move it.
@MainActor
@Observable
final class TodayPager {
    private(set) var page = 0
    /// How far a sideways drag has moved the pages with the finger.
    private(set) var pageDrag: CGFloat = 0
    /// The day shown: 0 today, 1 tomorrow, -1 yesterday.
    private(set) var dayOffset = 0
    /// How far the shown day has slid out to the side while the arrows change it.
    private(set) var daySlide: CGFloat = 0
    /// The direction of the drag in progress, decided by its first movement.
    private var swipeAxis: TodaySwipe.Axis?

    /// Turns to a page of `pageCount` (1 without pages: nothing to turn to).
    func turn(to newPage: Int, pageCount: Int, animation: Animation) {
        guard newPage != page, (0..<pageCount).contains(newPage) else { return }
        withAnimation(animation) {
            page = newPage
            pageDrag = 0
        }
    }

    /// Another arrangement starts at its first page.
    func resetPage() {
        page = 0
        pageDrag = 0
    }

    /// On pages a sideways drag moves them with the finger; past the first or last page it does nothing (the day
    /// changes with the arrows).
    func swipeChanged(_ translation: CGSize, pageCount: Int, gestures: RulesConfig.Gestures) {
        let axis = TodaySwipe.axis(locked: swipeAxis, width: translation.width, height: translation.height,
                                   axisRatio: gestures.daySwipeAxisRatio)
        swipeAxis = axis
        guard axis == .horizontal, TodaySwipe.page(forward: translation.width < 0, page: page, pageCount: pageCount) != nil else { return }
        pageDrag = translation.width
    }

    /// Far enough, or flung, the drag turns the page; otherwise the pages go back.
    func swipeEnded(_ translation: CGSize, predicted: CGSize, containerWidth: CGFloat, pageCount: Int,
                    gestures: RulesConfig.Gestures, animation: Animation) {
        let axis = TodaySwipe.axis(locked: swipeAxis, width: translation.width, height: translation.height,
                                   axisRatio: gestures.daySwipeAxisRatio)
        swipeAxis = nil
        let isSwipe = TodaySwipe.isSwipe(axis: axis, width: translation.width, predictedWidth: predicted.width,
                                         containerWidth: containerWidth, gestures: gestures)
        if isSwipe, let target = TodaySwipe.page(forward: translation.width < 0, page: page, pageCount: pageCount) {
            turn(to: target, pageCount: pageCount, animation: animation)
        } else {
            withAnimation(animation) { pageDrag = 0 }
        }
    }

    /// Yesterday / tomorrow: the day slides out to the side and the other one slides in, each in half of `duration`.
    func changeDay(by step: Int, width: CGFloat, duration: Double) {
        let half = duration / 2
        withAnimation(.easeIn(duration: half)) { daySlide = step > 0 ? -width : width } completion: {
            self.dayOffset += step
            self.daySlide = step > 0 ? width : -width
            withAnimation(.easeOut(duration: half)) { self.daySlide = 0 }
        }
    }

    func showToday(animation: Animation) {
        guard dayOffset != 0 else { return }
        withAnimation(animation) { dayOffset = 0 }
    }
}
