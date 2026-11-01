import CoreGraphics
import SwiftUI
import Testing

/// The alpha of every pixel of a view rendered at one pixel per point, for tests that look at what is drawn where.
@MainActor
struct RenderedAlpha {
    let width: Int
    let height: Int
    private let pixels: [UInt8]

    init(_ view: some View) throws {
        let renderer = ImageRenderer(content: view)
        renderer.scale = 1
        let image = try #require(renderer.cgImage)
        width = image.width
        height = image.height
        var pixels = [UInt8](repeating: 0, count: width * height * 4)
        let context = try #require(CGContext(data: &pixels, width: width, height: height, bitsPerComponent: 8,
                                             bytesPerRow: width * 4, space: CGColorSpaceCreateDeviceRGB(),
                                             bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        self.pixels = pixels
    }

    func alpha(x: Int, y: Int) -> UInt8 { pixels[(y * width + x) * 4 + 3] }

    func row(_ y: Int) -> [UInt8] { (0..<width).map { alpha(x: $0, y: y) } }

    /// The rows with a pixel more opaque than `threshold` at `fromX` or right of it.
    func inkedRows(fromX: Int = 0, threshold: UInt8 = 200) -> [Int] {
        (0..<height).filter { y in (fromX..<width).contains { alpha(x: $0, y: y) > threshold } }
    }

    /// The columns with a pixel more opaque than `threshold`.
    func inkedColumns(threshold: UInt8 = 200) -> [Int] {
        (0..<width).filter { x in (0..<height).contains { alpha(x: x, y: $0) > threshold } }
    }
}
