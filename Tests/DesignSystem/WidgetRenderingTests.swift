import Testing
import WidgetKit
@testable import SuperPooperApp

/// A widget rendered in one tint keeps only how opaque each view is: plates must stay fainter than the titles on them.
struct WidgetRenderingTests {
    private let tokens = TestConfig.tokens

    @Test(arguments: [PlateCorners.group, .row, .piece, .timelineItem])
    func inFullColorAPlateKeepsItsColor(corners: PlateCorners) {
        #expect(WidgetRendering.plateOpacity(corners, in: .fullColor, tokens: tokens) == 1)
    }

    @Test(arguments: [WidgetRenderingMode.accented, .vibrant])
    func inOneTintAPlateIsSeeThrough(mode: WidgetRenderingMode) {
        let opacity = WidgetRendering.plateOpacity(.row, in: mode, tokens: tokens)
        #expect(opacity == tokens.opacity(.accentedPlate))
        #expect(opacity > 0 && opacity < 1)
    }

    /// A routine's habits lie on the routine's plate: their own pieces would make it twice as solid as a task's plate.
    @Test(arguments: [WidgetRenderingMode.accented, .vibrant])
    func inOneTintAPieceAddsNothingToItsPlate(mode: WidgetRenderingMode) {
        #expect(WidgetRendering.plateOpacity(.piece, in: mode, tokens: tokens) == 0)
    }
}
