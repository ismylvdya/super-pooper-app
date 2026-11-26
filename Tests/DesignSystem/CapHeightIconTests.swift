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

    @Test func contextMenuFitsHabitAssetsAndSymbolsToTheSameExtent() throws {
        let extent: CGFloat = 18
        let icons = TestConfig.decode(IconSet.self, "icons.json")
        for name in [icons[.started], icons[.habitMarkDone], "forward.end", "number", "trash"] {
            let icon = try #require(TemplateGlyph.menuImage(name, extent: extent, scale: scale))
            let ink = InkBounds.of(icon, scale: scale)
            #expect(abs(max(ink.width, ink.height) - extent) <= 1 / scale)
        }
    }
}
