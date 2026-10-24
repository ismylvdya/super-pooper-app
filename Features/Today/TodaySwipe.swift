import Foundation

/// What a horizontal swipe on Today does. Leftwards is forward. With pages, a swipe first turns to the
/// timeline (or back to the pool); past the last page it changes the day.
enum TodaySwipe {
    enum Move: Equatable {
        case page(Int)
        case day(Int)
    }

    static func move(forward: Bool, page: Int, pageCount: Int) -> Move {
        if forward, page < pageCount - 1 { return .page(page + 1) }
        if !forward, page > 0 { return .page(page - 1) }
        return .day(forward ? 1 : -1)
    }
}
