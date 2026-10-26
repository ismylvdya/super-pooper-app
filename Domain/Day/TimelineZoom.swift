import Foundation

/// Pinch on the timeline: the moment between the fingers stays where it is while the hours grow or shrink.
enum TimelineZoom {
    /// The scroll offset that keeps the moment at `anchorY` (points from the scroll view's top) in place when the
    /// hour height goes from `oldHeight` to `newHeight`. `startOffset` is the offset when the pinch began; the
    /// hours start `contentTop` points into the content.
    static func offset(keeping anchorY: Double, startOffset: Double, contentTop: Double,
                       from oldHeight: Double, to newHeight: Double) -> Double {
        let hours = (startOffset + anchorY - contentTop) / max(oldHeight, 1)
        return contentTop + hours * newHeight - anchorY
    }
}
