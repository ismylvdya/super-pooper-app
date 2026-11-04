import SwiftUI

/// The column of hour numbers on the timeline's left, and what lines up with those numbers.
extension DesignTokens {
    /// The column grows with the hour font.
    var hourColumnWidth: CGFloat { scaled(space(.timelineLabelWidth), with: .timelineHour) }

    /// The x of the middle of the hour numbers, counted from the column's left edge.
    var hourDigitsCenter: CGFloat {
        hourColumnWidth - space(.hourLabelGap) - scaled(size(.hourDigitsWidth), with: .timelineHour) / 2
    }
}
