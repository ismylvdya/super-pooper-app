import Foundation

/// Where the timeline opens: scrolled so the first shown hour (N hours before now, or the start of the
/// day range) is at the top, under the all-day strip. The all-day events can arrive after the timeline is
/// on screen; until the user scrolls, the opening position follows the strip's height.
struct TimelineOpening: Equatable {
    /// Distance from the start of the logical day to the first shown hour, in points.
    let startOffset: Double
    private(set) var stripHeight: Double
    private(set) var isUserScrolled = false

    init(startOffset: Double, stripHeight: Double) {
        self.startOffset = startOffset
        self.stripHeight = stripHeight
    }

    var offset: Double { max(startOffset - stripHeight, 0) }

    /// The offset to scroll to when the strip changes height, or nil once the user has scrolled.
    mutating func stripChanged(to height: Double) -> Double? {
        stripHeight = height
        return isUserScrolled ? nil : offset
    }

    mutating func userScrolled() {
        isUserScrolled = true
    }
}
