import SwiftUI
import UIKit

/// A hand-drawn glyph of the asset catalog (a template vector image) drawn where an SF Symbol would stand: cut to its
/// ink and scaled so that ink is as tall (or as wide) as asked, then tinted like a symbol by the text color.
@MainActor
enum TemplateGlyph {
    private static var inks: [String: CGRect] = [:]
    private static var drawn: [String: UIImage] = [:]

    /// The asset with that name; nil for an SF Symbol name.
    static func asset(_ name: String) -> UIImage? { UIImage(named: name) }

    /// The ink of the asset with that name, in its points.
    static func ink(of name: String, scale: CGFloat) -> CGRect? {
        guard let glyph = asset(name) else { return nil }
        return ink(of: glyph, key: name, scale: scale)
    }

    /// The asset's ink, `extent` points along `axis`, nothing around it; nil when `name` is not an asset.
    static func image(_ name: String, extent: CGFloat, along axis: Axis, scale: CGFloat) -> UIImage? {
        guard let glyph = asset(name) else { return nil }
        return trimmed(glyph, key: name, extent: extent, along: axis, scale: scale)
    }

    /// The SF Symbol with that name cut and scaled the same way; nil when there is no such symbol.
    static func symbol(_ name: String, extent: CGFloat, along axis: Axis, scale: CGFloat) -> UIImage? {
        guard let glyph = UIImage(systemName: name, withConfiguration: UIImage.SymbolConfiguration(pointSize: extent)) else { return nil }
        return trimmed(glyph, key: "symbol:\(name)|\(extent)", extent: extent, along: axis, scale: scale)
    }

    private static func ink(of glyph: UIImage, key name: String, scale: CGFloat) -> CGRect {
        let key = "\(name)|\(scale)"
        if let cached = inks[key] { return cached }
        let ink = InkBounds.of(glyph, scale: scale)
        inks[key] = ink
        return ink
    }

    private static func trimmed(_ glyph: UIImage, key name: String, extent: CGFloat, along axis: Axis, scale: CGFloat) -> UIImage? {
        let ink = ink(of: glyph, key: name, scale: scale)
        guard ink.width > 0, ink.height > 0 else { return nil }
        let key = "\(name)|\(extent)|\(axis)|\(scale)"
        if let cached = drawn[key] { return cached }
        let factor = extent / (axis == .vertical ? ink.height : ink.width)
        let format = UIGraphicsImageRendererFormat.preferred()
        format.scale = scale
        let size = CGSize(width: ink.width * factor, height: ink.height * factor)
        let image = UIGraphicsImageRenderer(size: size, format: format).image { _ in
            glyph.draw(in: CGRect(x: -ink.minX * factor, y: -ink.minY * factor,
                                  width: glyph.size.width * factor, height: glyph.size.height * factor))
        }
        .withRenderingMode(.alwaysTemplate)
        drawn[key] = image
        return image
    }
}
