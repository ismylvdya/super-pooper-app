import Testing
import UIKit
@testable import SuperPooperApp

/// Swipe buttons look alike in every list: the symbol and the title are one image, which the system always draws inside
/// the button, whatever the row's height.
@MainActor
struct SwipeButtonGlyphTests {
    private let tokens = TestConfig.tokens
    private let scale: CGFloat = 3

    @Test func theTitleStandsUnderTheSymbolInOneTemplateImage() throws {
        let done = TestConfig.actions.definition(.done)
        let iconFont = tokens.uiFont(.swipeIcon)
        let titleFont = tokens.uiFont(.swipeTitle)
        let gap = tokens.space(.swipeIconTitleGap)
        let image = SwipeButtonGlyph.image(symbol: done.icon, title: L10n.string(done.title), iconFont: iconFont,
                                           titleFont: titleFont, gap: gap, scale: scale)
        let icon = try #require(UIImage(systemName: done.icon, withConfiguration: UIImage.SymbolConfiguration(font: iconFont)))
        let title = NSAttributedString(string: L10n.string(done.title), attributes: [.font: titleFont]).size()
        #expect(image.renderingMode == .alwaysTemplate, "tinted by the button like a symbol")
        #expect(image.size.height >= icon.size.height + gap + title.height)
        #expect(image.size.width >= max(icon.size.width, title.width))
        let ink = InkBounds.of(image, scale: scale)
        #expect(ink.maxY > icon.size.height + gap, "the title is drawn under the symbol")
    }

    /// The symbol and the title keep clear of the button's edges on a one-line row (44 points, the system's least).
    @Test func theGlyphLeavesRoomInsideTheButton() {
        let done = TestConfig.actions.definition(.done)
        let image = SwipeButtonGlyph.image(symbol: done.icon, title: L10n.string(done.title), iconFont: tokens.uiFont(.swipeIcon),
                                           titleFont: tokens.uiFont(.swipeTitle), gap: tokens.space(.swipeIconTitleGap), scale: scale)
        #expect(image.size.height <= 44 * 0.75)
    }

    @Test func everySwipeActionHasASymbol() {
        for kind in ActionSwipes.allCases {
            let set = TestConfig.actions.swipes[kind]
            for id in set.leading + set.trailing {
                #expect(UIImage(systemName: TestConfig.actions.definition(id).icon) != nil, "\(id)")
            }
        }
    }
}
