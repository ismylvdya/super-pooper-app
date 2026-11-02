import SwiftUI
import Testing
@testable import SuperPooperApp

/// A habit day on a plate has an opaque backing of the plate's color in the shape of its outer edge (.24670): lifted by a
/// long press, Twice or Partially is not see-through between its rings and dot, and the neighbouring days never show.
@MainActor
struct HabitDayCellTests {
    private let metrics = HabitDotMetrics(dot: 40, ringRatio: 0.1)

    @Test func theBackingIsAsLargeAsTheDaysOuterEdge() {
        #expect(metrics.outline(of: .twice) == metrics.cell)
        for cell in [HabitCell.done, .partial, .open, .missed, .notScheduled] {
            #expect(metrics.outline(of: cell) == metrics.dot)
        }
        #expect(metrics.outline(of: .future) == nil)
    }

    @Test(arguments: [HabitCell.twice, .partial, .open, .done])
    func onAPlateADayIsOpaqueEverywhereInsideItsOuterEdge(_ cell: HabitCell) throws {
        let alphas = try middleRowAlphas(HabitDayCell(cell: cell, color: .black, metrics: metrics).environment(\.plateSurface, .white))
        let center = Int(metrics.cell / 2)
        // Up to two points short of the edge, where the circle's antialiasing starts.
        let reach = Int(try #require(metrics.outline(of: cell)) / 2) - 2
        #expect(alphas[center...(center + reach)].allSatisfy { $0 == 255 })
    }

    @Test func offAPlateADayHasNoBacking() throws {
        let alphas = try middleRowAlphas(HabitDayCell(cell: .twice, color: .black, metrics: metrics))
        let gap = Int(metrics.cell / 2 + metrics.dot / 2 + metrics.ring / 2)
        #expect(alphas[gap] == 0, "a widget lies on its own background, not on a plate")
    }

    /// The ring of a day not done or done partly stands at `opacity.habitOpenRing` (.27670); Done and Twice keep the color.
    @Test(arguments: [HabitCell.open, .partial, .missed])
    func theRingOfAnOpenDayIsFaded(_ cell: HabitCell) throws {
        let tokens = TestConfig.tokens
        let alphas = try middleRowAlphas(HabitDayCell(cell: cell, color: .black, metrics: metrics).designTokens(tokens))
        let ring = Int(metrics.cell / 2 - metrics.dot / 2 + metrics.ring / 2)
        #expect(abs(Double(alphas[ring]) - 255 * tokens.opacity(.habitOpenRing)) <= 3)
        let done = try middleRowAlphas(HabitDayCell(cell: .twice, color: .black, metrics: metrics).designTokens(tokens))
        #expect(done[Int(metrics.cell / 2)] == 255)
    }

    /// The habits settings set it, within `rules.json` → `limits.ringOpacity`.
    @Test func theSettingsSetTheRingsOpacity() {
        var settings = TestConfig.defaults
        #expect(settings.habits.ringOpacity == 0.5)
        settings.habits.ringOpacity = 0.3
        let limits = TestConfig.rules.limits
        #expect(TestConfig.tokens.applying(settings, limits: limits).opacity(.habitOpenRing) == 0.3)
        settings.habits.ringOpacity = 0
        #expect(TestConfig.tokens.applying(settings, limits: limits).opacity(.habitOpenRing) == limits.ringOpacity.min)
    }

    /// The alpha of each pixel in the middle row of the rendered view (one pixel per point).
    private func middleRowAlphas(_ view: some View) throws -> [UInt8] {
        let rendered = try RenderedAlpha(view)
        return rendered.row(rendered.height / 2)
    }
}
