import Testing
import UIKit
@testable import SuperPooperApp

/// Glyphs cut to their ink (`TemplateGlyph`).
@MainActor
struct CapHeightIconTests {
    private let scale: CGFloat = 3

    @Test func aNameThatIsNoSymbolHasNoImage() {
        #expect(TemplateGlyph.symbol("no.such.symbol.at.all", extent: 10, along: .vertical, scale: scale) == nil)
    }
}
