import SwiftUI
import UIKit

/// A tab icon from `icons.json`: an SF Symbol, or a glyph drawn by hand (a template image of the asset catalog with
/// that name). A glyph is scaled to match the other tabs' symbols at the same font: as tall as the tallest of them
/// (the bar upright, tabs side by side), or as wide as the widest (the bar sideways, tabs in a narrow column).
@MainActor
enum TabIconImage {
    enum Match { case height, width }

    private static var cache: [String: UIImage] = [:]

    static func image(_ name: String, font: UIFont, others: [String], matching match: Match = .height) -> Image {
        guard let glyph = UIImage(named: name) else { return Image(systemName: name) }
        let key = "\(name)|\(font.pointSize)|\(font.fontName)|\(match)"
        if let cached = cache[key] { return Image(uiImage: cached) }
        let configuration = UIImage.SymbolConfiguration(font: font)
        let sizes = others.compactMap { UIImage(systemName: $0, withConfiguration: configuration)?.size }
        let scale: CGFloat
        switch match {
        case .height: scale = (sizes.map(\.height).max() ?? font.lineHeight) / glyph.size.height
        case .width: scale = (sizes.map(\.width).max() ?? font.lineHeight) / glyph.size.width
        }
        let size = CGSize(width: glyph.size.width * scale, height: glyph.size.height * scale)
        let drawn = UIGraphicsImageRenderer(size: size).image { _ in glyph.draw(in: CGRect(origin: .zero, size: size)) }
            .withRenderingMode(.alwaysTemplate)
        cache[key] = drawn
        return Image(uiImage: drawn)
    }
}
