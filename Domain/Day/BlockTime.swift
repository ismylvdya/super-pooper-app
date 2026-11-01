import Foundation

/// Where one of an item's blocks stands today: `time`, and `written`, the time its note has (the same, unless a habit's
/// block was dragged to another time for today).
struct BlockTime: Hashable, Sendable {
    let written: LocalTime
    let time: LocalTime

    init(written: LocalTime, time: LocalTime) {
        self.written = written
        self.time = time
    }

    /// A block at the time its note has.
    init(_ time: LocalTime) {
        self.init(written: time, time: time)
    }

    var isMoved: Bool { written != time }
}
