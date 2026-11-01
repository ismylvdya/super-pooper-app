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

    /// Every plate takes its corner from one place: a group from `radius.plate`, a row concentric with its chips, a
    /// routine's piece square.
    @Test func eachKindOfPlateHasItsCorner() {
        let tokens = TestConfig.tokens
        #expect(tokens.plateRadius(.group) == tokens.radius(.plate))
        #expect(tokens.plateRadius(.row) == tokens.rowPlateRadius)
        #expect(tokens.plateRadius(.piece) == 0)
        #expect(tokens.plateRadius(.timelineItem) == tokens.radius(.timelineItem))
        #expect(tokens.plateRadius(.previewFrame) == tokens.radius(.previewFrame))
        #expect(tokens.plateShape(.group).cornerRadius == tokens.radius(.plate))
    }

    /// A row of a grouped list lifted for its menu or a drag (`plateLift`) has the corner of the backing it leaves —
    /// the same curve, not one rounded to half the row — as long as the row is taller than two corners; a shorter row
    /// is rounded by half its height.
    @Test func aLiftedRowHasTheBackingsCorner() {
        let tokens = TestConfig.tokens
        let radius = tokens.plateRadius(.group)
        let backing = tokens.plateShape(.group).path(in: CGRect(x: 0, y: 0, width: 360, height: 400))
        let row = tokens.plateShape(.group).path(in: CGRect(x: 0, y: 0, width: 360, height: radius * 2 + 10))
        let corner = stride(from: 0.5, through: radius, by: 0.5).map { CGPoint(x: $0, y: $0 / 2) }
        #expect(corner.map { row.contains($0) } == corner.map { backing.contains($0) })
        let short = CGRect(x: 0, y: 0, width: 360, height: radius)
        let capsule = RoundedRectangle(cornerRadius: radius / 2, style: .continuous).path(in: short)
        #expect(tokens.plateShape(.group).path(in: short).description == capsule.description)
    }

    @Test func theFadeKeepsTheSameGapBeforeAnythingOnItsRight() {
        #expect(TitleFade.trailing(corner: 0, plateInset: 5, gap: 8) == 3)
        #expect(TitleFade.trailing(corner: 30, plateInset: 5, gap: 8) == 33)
        #expect(TitleFade.trailing(corner: 30, plateInset: 8, gap: 8) == 30)
    }
}
