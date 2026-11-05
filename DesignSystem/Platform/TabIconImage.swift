import SwiftUI
import UIKit

/// A tab icon from `icons.json`: an SF Symbol, or a glyph drawn by hand (a template image of the asset catalog with
/// that name). A glyph stands within the other tabs' symbols at the same font: its ink is `systemBar.metric.tabGlyphFit`
/// of the smallest of their inks, in height with the bar upright (tabs side by side), in width with the bar sideways
/// (tabs in a narrow column).
@MainActor
enum TabIconImage {
    enum Match { case height, width }

    private static var extents: [String: CGFloat] = [:]

    static func image(_ name: String, font: UIFont, others: [String], matching match: Match = .height, fit: CGFloat,
                      scale: CGFloat) -> Image {
        let axis: Axis = match == .height ? .vertical : .horizontal
        guard TemplateGlyph.asset(name) != nil,
              let glyph = TemplateGlyph.image(name, extent: glyphExtent(font: font, others: others, along: axis, fit: fit, scale: scale),
                                              along: axis, scale: scale)
        else { return Image(systemName: name) }
        return Image(uiImage: glyph)
    }

    /// The same glyph for a place that takes a UIKit image (the bar's selected item); nil for an SF Symbol.
    static func glyph(_ name: String, font: UIFont, others: [String], fit: CGFloat, scale: CGFloat) -> UIImage? {
        guard TemplateGlyph.asset(name) != nil else { return nil }
        return TemplateGlyph.image(name, extent: glyphExtent(font: font, others: others, along: .vertical, fit: fit, scale: scale),
                                   along: .vertical, scale: scale)
    }

    /// How far a hand-drawn glyph's ink reaches along `axis`: `fit` of the smallest ink of the other tabs' symbols.
    static func glyphExtent(font: UIFont, others: [String], along axis: Axis, fit: CGFloat, scale: CGFloat) -> CGFloat {
        let key = "\(font.fontName)|\(font.pointSize)|\(others)|\(axis)|\(fit)|\(scale)"
        if let cached = extents[key] { return cached }
        let configuration = UIImage.SymbolConfiguration(font: font)
        let inks = others.compactMap { name in
            UIImage(systemName: name, withConfiguration: configuration).map { InkBounds.of($0, scale: scale) }
        }
        let extent = (inks.map { axis == .vertical ? $0.height : $0.width }.min() ?? font.capHeight) * fit
        extents[key] = extent
        return extent
    }
}
