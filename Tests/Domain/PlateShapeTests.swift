import SwiftUI
import Testing
@testable import SuperPooperApp

/// A plate never rounds past half its shorter side, so a short slot or a lifted row stays a plate, not a lens.
struct PlateShapeTests {
    @Test func cornersAreCappedByHalfTheHeight() {
        let short = CGRect(x: 0, y: 0, width: 200, height: 20)
        let capped = PlateShape(cornerRadius: 30).path(in: short)
        let expected = RoundedRectangle(cornerRadius: 10, style: .continuous).path(in: short)
        #expect(capped.description == expected.description)
    }

    @Test func theFadeKeepsTheSameGapBeforeAnythingOnItsRight() {
        #expect(TitleFade.trailing(corner: 0, plateInset: 5, gap: 8) == 3)
        #expect(TitleFade.trailing(corner: 30, plateInset: 5, gap: 8) == 33)
        #expect(TitleFade.trailing(corner: 30, plateInset: 8, gap: 8) == 30)
    }
}
