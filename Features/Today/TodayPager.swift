import SwiftUI

/// Where Tasks stands: the page of its strip (`TasksPageStrip`) and how far a finger has moved it, the backlog pages
/// opened left of the pool and how far the first page is pulled to open the next one, the day shown and how far it has
/// slid out. The screen draws from it; the swipe, the page edge, a dragged task, the arrows and the Tasks tab move it.
@MainActor
@Observable
final class TodayPager {
    /// The page of the strip shown; opening a backlog page puts it at index 0, where the page shown already was.
    private(set) var page = 0
    /// How far a sideways drag has moved the pages with the finger.
    private(set) var pageDrag: CGFloat = 0
    /// How many backlog pages stand left of the pool (0…the backlog's count).
    private(set) var openedBacklog = 0
    /// How far the first page is pulled right to open the next backlog page (the finger's way, resisted).
    private(set) var sidePull: CGFloat = 0
    private var arming = PullArming()
    /// The pull has gone far enough: letting go opens the next backlog page.
    var isPullArmed: Bool { arming.isArmed }
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

    /// Another arrangement starts at its first page, without the backlog pages.
    func resetPage() {
        closeBacklog()
    }

    /// The backlog pages are forgotten (another tab was opened): Tasks shows the pool's page, `poolBlock` of the day's
    /// pages.
    func closeBacklog(poolBlock: Int = 0) {
        openedBacklog = 0
        page = poolBlock
        pageDrag = 0
        sidePull = 0
        arming = PullArming()
    }

    /// On pages a sideways drag moves them with the finger, all the way until it lifts; past the last page it does
    /// nothing, and at the first one a rightward drag pulls it to open the next of `backlogCount` backlog pages (the day
    /// changes with the arrows). True when the pull has just armed: the moment to feel.
    @discardableResult
    func swipeChanged(_ translation: CGSize, containerWidth: CGFloat, pageCount: Int, backlogCount: Int = 0,
                      gestures: RulesConfig.Gestures) -> Bool {
        let axis = TodaySwipe.axis(locked: swipeAxis, width: translation.width, height: translation.height,
                                   axisRatio: gestures.daySwipeAxisRatio)
        swipeAxis = axis
        guard axis == .horizontal else { return false }
        if page == 0, translation.width > 0, openedBacklog < backlogCount {
            pageDrag = 0
            sidePull = PullArming.stretch(translation.width, dimension: containerWidth, resistance: gestures.pullResistance)
            return arming.update(pull: sidePull, threshold: gestures.pullThreshold)
        }
        if sidePull != 0 {
            sidePull = 0
            _ = arming.update(pull: 0, threshold: gestures.pullThreshold)
        }
        guard TodaySwipe.page(forward: translation.width < 0, page: page, pageCount: pageCount) != nil else { return false }
        pageDrag = translation.width
        return false
    }

    /// The drag is not a swipe after all (a task is being dragged): the pages stay where they are.
    func cancelSwipe() {
        swipeAxis = nil
        _ = arming.release()
        guard pageDrag != 0 || sidePull != 0 else { return }
        pageDrag = 0
        sidePull = 0
    }

    /// Once the finger lifts: a pull that armed opens the next backlog page, which slides in at index 0 (true then);
    /// past `daySwipeShare` of the width or flung far enough, the page turns at the finger's speed; otherwise the pages go
    /// back.
    @discardableResult
    func swipeEnded(_ translation: CGSize, predicted: CGSize, velocity: CGSize = .zero, containerWidth: CGFloat, pageCount: Int,
                    backlogCount: Int = 0, gestures: RulesConfig.Gestures, duration: Double) -> Bool {
        let axis = TodaySwipe.axis(locked: swipeAxis, width: translation.width, height: translation.height,
                                   axisRatio: gestures.daySwipeAxisRatio)
        swipeAxis = nil
        if sidePull > 0 {
            let opens = arming.release() && openedBacklog < backlogCount
            withAnimation(.interpolatingSpring(duration: duration, bounce: 0)) {
                if opens { openedBacklog += 1 }
                sidePull = 0
            }
            return opens
        }
        _ = arming.release()
        let isSwipe = TodaySwipe.isSwipe(axis: axis, width: translation.width, predictedWidth: predicted.width,
                                         containerWidth: containerWidth, gestures: gestures)
        if isSwipe, let target = TodaySwipe.page(forward: translation.width < 0, page: page, pageCount: pageCount) {
            finish(to: target, speed: velocity.width, containerWidth: containerWidth, duration: duration)
        } else {
            withAnimation(.easeInOut(duration: duration)) { pageDrag = 0 }
        }
        return false
    }

    /// The rest of the way to the page, starting at the finger's speed and slowing down to rest, as a scroll view's page does.
    private func finish(to target: Int, speed: CGFloat, containerWidth: CGFloat, duration: Double) {
        let remaining = max(Double(containerWidth - abs(pageDrag)), 0)
        let velocity = TodaySwipe.initialVelocity(speed: Double(speed), remaining: remaining)
        withAnimation(.interpolatingSpring(duration: duration, bounce: 0, initialVelocity: velocity)) {
            page = target
            pageDrag = 0
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

    /// The day's name: today, on the pool's page (`poolBlock` of the day's pages, after the backlog pages open).
    /// The Tasks tab also forgets the backlog pages (`forgetsBacklog`).
    func showPool(poolBlock: Int = 0, forgetsBacklog: Bool = false, animation: Animation) {
        let opened = forgetsBacklog ? 0 : openedBacklog
        let home = opened + poolBlock
        guard dayOffset != 0 || page != home || pageDrag != 0 || opened != openedBacklog else { return }
        withAnimation(animation) {
            dayOffset = 0
            openedBacklog = opened
            page = home
            pageDrag = 0
            sidePull = 0
        }
    }
}
