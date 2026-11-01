import CoreGraphics
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

    /// The alpha of each pixel in the middle row of the rendered view (one pixel per point).
    private func middleRowAlphas(_ view: some View) throws -> [UInt8] {
        let renderer = ImageRenderer(content: view)
        renderer.scale = 1
        let image = try #require(renderer.cgImage)
        let width = image.width
        var pixels = [UInt8](repeating: 0, count: width * image.height * 4)
        let context = try #require(CGContext(data: &pixels, width: width, height: image.height, bitsPerComponent: 8,
                                             bytesPerRow: width * 4, space: CGColorSpaceCreateDeviceRGB(),
                                             bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: image.height))
        let row = image.height / 2
        return (0..<width).map { pixels[(row * width + $0) * 4 + 3] }
    }
}
