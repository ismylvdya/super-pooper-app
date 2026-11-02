import Testing
import UIKit
@testable import SuperPooperApp

/// The bells under a habit's name (.28006): as tall as a capital letter of their line, smaller than the symbol the line's
/// font would draw.
@MainActor
struct CapHeightIconTests {
    private let icons = TestConfig.decode(IconSet.self, "icons.json")
    private let tokens = TestConfig.tokens
    private let scale: CGFloat = 3

    @Test func aBellIsAsTallAsTheLinesCapitalLetters() throws {
        let font = tokens.uiFont(HabitRow.detailFont)
        let bell = try #require(TemplateGlyph.symbol(icons[.bell], extent: font.capHeight, along: .vertical, scale: scale))
        #expect(abs(bell.size.height - font.capHeight) < 1 / scale)
        let inFont = try #require(UIImage(systemName: icons[.bell], withConfiguration: UIImage.SymbolConfiguration(font: font)))
        #expect(bell.size.height < InkBounds.of(inFont, scale: scale).height, "smaller than the font's own bell")
    }

    @Test func aNameThatIsNoSymbolHasNoImage() {
        #expect(TemplateGlyph.symbol("no.such.symbol.at.all", extent: 10, along: .vertical, scale: scale) == nil)
    }

    /// Every habit row is as tall as one with a detail line under its name.
    @Test func everyHabitRowHasTheHeightOfOneWithADetail() {
        let name = tokens.uiFont(.habitTitle).lineHeight
        let detail = tokens.uiFont(HabitRow.detailFont).lineHeight
        let gap = tokens.space(.titleDetailGap)
        #expect(HabitRowHeight.text(name: name, gap: gap, detail: detail) == name + gap + detail)
    }
}
