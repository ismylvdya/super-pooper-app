import Foundation

/// What a horizontal swipe on Today does. Leftwards is forward. With pages, a swipe first turns to the
/// timeline (or back to the pool); past the last page it changes the day.
enum TodaySwipe {
    enum Move: Equatable {
        case page(Int)
        case day(Int)
    }

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

    static func move(forward: Bool, page: Int, pageCount: Int) -> Move {
        if forward, page < pageCount - 1 { return .page(page + 1) }
        if !forward, page > 0 { return .page(page - 1) }
        return .day(forward ? 1 : -1)
    }
}
