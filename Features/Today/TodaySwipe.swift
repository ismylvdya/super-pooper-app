import Foundation

/// What a horizontal swipe on Today does: with pages, it turns to the timeline (or back to the pool); the day
/// is changed with the buttons next to its name, not by swiping. Leftwards is forward.
enum TodaySwipe {
    /// A drag is sideways when it moves `axisRatio` times more across than up or down.
    static func isHorizontal(width: Double, height: Double, axisRatio: Double) -> Bool {
        abs(width) > abs(height) * axisRatio
    }

    /// A finished sideways drag counts when it went past `threshold` of the width or was flung past half of it.
    static func isSwipe(width: Double, height: Double, predictedWidth: Double, containerWidth: Double,
                        threshold: Double, axisRatio: Double) -> Bool {
        isHorizontal(width: width, height: height, axisRatio: axisRatio)
            && (abs(width) > containerWidth * threshold || abs(predictedWidth) > containerWidth / 2)
    }

    /// The page a swipe turns to; nil past the first or last page.
    static func page(forward: Bool, page: Int, pageCount: Int) -> Int? {
        if forward, page < pageCount - 1 { return page + 1 }
        if !forward, page > 0 { return page - 1 }
        return nil
    }
}
