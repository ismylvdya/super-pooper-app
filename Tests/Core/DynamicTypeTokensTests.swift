import SwiftUI
import Testing
@testable import SuperPooperApp

/// Fonts and the lengths drawn with them follow the reader's text size where they are used, fixed sizes included.
struct DynamicTypeTokensTests {
    private let tokens = TestConfig.tokens

    /// At the default text size a fixed size is the size written in tokens.json; larger text makes it larger.
    @Test func aFixedSizeFontScalesWithTheTextSize() {
        let standard = tokens.measured(at: .large)
        let large = tokens.measured(at: .xxxLarge)
        #expect(standard.uiFont(.pageTitle).pointSize == 34)
        #expect(large.uiFont(.pageTitle).pointSize > 34)
        #expect(large.uiFont(.linkBadge).pointSize > standard.uiFont(.linkBadge).pointSize)
    }

    /// UIKit line heights come from the text size of the place, not from the phone's global setting.
    @Test func uiKitMetricsFollowTheEnvironmentsTextSize() {
        let small = tokens.measured(at: .xSmall)
        let large = tokens.measured(at: .accessibility2)
        #expect(small.uiFont(.chip).lineHeight < large.uiFont(.chip).lineHeight)
        #expect(small.chipHeight < large.chipHeight)
    }

    /// The hour column of the timeline is 28 pt at the default size and grows with the hour labels' font.
    @Test func theTimelineHourColumnGrowsWithItsFont() {
        let width = tokens.space(.timelineLabelWidth)
        #expect(tokens.measured(at: .large).scaled(width, with: .timelineHour) == width)
        #expect(tokens.measured(at: .accessibility1).scaled(width, with: .timelineHour) > width)
    }

    /// A fixed size must name the text style it scales with; a text style needs none.
    @Test func aFixedSizeNamesTheStyleItScalesWith() {
        let missing = Data(#"{"size": 34, "weight": "bold"}"#.utf8)
        let needless = Data(#"{"style": "body", "relativeTo": "body"}"#.utf8)
        #expect(throws: ConfigError.self) { try ConfigLoader.decode(FontSpec.self, from: missing, file: "tokens.json") }
        #expect(throws: ConfigError.self) { try ConfigLoader.decode(FontSpec.self, from: needless, file: "tokens.json") }
    }

    /// A size picked in settings (the timeline's fonts) is drawn as picked, in the token's weight, at any text size.
    @Test func aPickedSizeIsUsedAsIs() {
        let large = tokens.measured(at: .accessibility3)
        #expect(large.uiFont(.timelineText, size: 17).pointSize == 17)
        #expect(large.uiFont(.timelineEvent, size: 15).fontDescriptor.symbolicTraits.contains(.traitBold))
    }

    /// The habit dots never shrink below the token's minimum, however narrow the grid.
    @Test func habitDotsHaveAMinimum() {
        #expect(tokens.habitDots(fitting: 0).dot == tokens.size(.habitDotMinimum))
    }

    /// The habit widget's weeks start from the widget settings' own default.
    @Test func theHabitWidgetWeeksDefaultIsTheIntents() {
        #expect(HabitWidgetOptions().weeks == SelectHabitIntent().weeks)
        #expect(HabitWidgetOptions().weeks == 4)
    }
}
