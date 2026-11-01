import UIKit

/// Where an image actually draws: the box around its painted pixels, in the image's points. A symbol's or an asset's
/// size includes the empty room around its drawing; glyphs that must stand within each other are compared by this.
enum InkBounds {
    /// `scale`: pixels per point the image is looked at, the screen's own for a box exact to its pixels.
    static func of(_ image: UIImage, scale resolution: CGFloat) -> CGRect {
        let width = Int((image.size.width * resolution).rounded(.up))
        let height = Int((image.size.height * resolution).rounded(.up))
        guard width > 0, height > 0,
              let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width,
                                      space: CGColorSpaceCreateDeviceGray(), bitmapInfo: CGImageAlphaInfo.alphaOnly.rawValue),
              let alpha = context.data?.bindMemory(to: UInt8.self, capacity: width * height)
        else { return CGRect(origin: .zero, size: image.size) }
        context.interpolationQuality = .none
        context.translateBy(x: 0, y: CGFloat(height))
        context.scaleBy(x: resolution, y: -resolution)
        UIGraphicsPushContext(context)
        image.draw(in: CGRect(origin: .zero, size: image.size))
        UIGraphicsPopContext()
        var minX = width, minY = height, maxX = -1, maxY = -1
        for y in 0..<height {
            for x in 0..<width where alpha[y * width + x] > 0 {
                minX = min(minX, x); maxX = max(maxX, x)
                minY = min(minY, y); maxY = max(maxY, y)
            }
        }
        guard maxX >= minX else { return .zero }
        return CGRect(x: CGFloat(minX) / resolution, y: CGFloat(minY) / resolution,
                      width: CGFloat(maxX - minX + 1) / resolution, height: CGFloat(maxY - minY + 1) / resolution)
    }
}
