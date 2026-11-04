import SwiftUI
import UIKit

/// The column of hour numbers on the timeline's left, and what lines up with those numbers.
extension DesignTokens {
    /// The column grows with the hour font.
    var hourColumnWidth: CGFloat { scaled(space(.timelineLabelWidth), with: .timelineHour) }

    /// The x of the vertical all the hour numbers are centered on, counted from the column's left edge: two digits end at
    /// the column's right less the gap, and how wide they are is measured in the font they are drawn in, whatever the
    /// screen and text size.
    var hourDigitsCenter: CGFloat {
        hourColumnWidth - space(.hourLabelGap) - hourDigitsWidth / 2
    }

    var hourDigitsWidth: CGFloat {
        let font = uiFont(.timelineHour)
        let monospaced = font.fontDescriptor.addingAttributes([.featureSettings: [[
            UIFontDescriptor.FeatureKey.type: kNumberSpacingType,
            UIFontDescriptor.FeatureKey.selector: kMonospacedNumbersSelector,
        ]]])
        return ceil(("00" as NSString).size(withAttributes: [.font: UIFont(descriptor: monospaced, size: 0)]).width)
    }
}
