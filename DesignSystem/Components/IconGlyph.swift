import SwiftUI
import UIKit

/// An icon from `icons.json` in a line of text set in `font`: an SF Symbol takes the font from the environment as text
/// does; a hand-drawn template glyph of the asset catalog (the frog of Need energy) stands as tall as the font's wide
/// symbols (`ratio.handGlyph`). Both are tinted by the foreground style.
struct IconGlyph: View {
    @Environment(\.tokens) private var tokens
    @Environment(\.icons) private var icons
    @Environment(\.displayScale) private var scale
    let icon: Icon
    let font: FontToken

    init(_ icon: Icon, font: FontToken) {
        self.icon = icon
        self.font = font
    }

    var body: some View {
        if let glyph = Self.glyph(icons[icon], font: tokens.uiFont(font), tokens: tokens, scale: scale) {
            Image(uiImage: glyph)
        } else {
            Image(systemName: icons[icon])
        }
    }

    /// The hand-drawn glyph with that name at a font; nil for an SF Symbol.
    @MainActor
    static func glyph(_ name: String, font: UIFont, tokens: DesignTokens, scale: CGFloat) -> UIImage? {
        TemplateGlyph.image(name, extent: font.capHeight * tokens.ratio(.handGlyph), along: .vertical, scale: scale)
    }

    /// The size the icon takes at a font, for a layout that needs it before anything is drawn.
    @MainActor
    static func size(of icon: Icon, font: UIFont, tokens: DesignTokens, icons: IconSet, scale: CGFloat) -> CGSize {
        if let glyph = glyph(icons[icon], font: font, tokens: tokens, scale: scale) { return glyph.size }
        return UIImage(systemName: icons[icon], withConfiguration: UIImage.SymbolConfiguration(font: font))?.size ?? .zero
    }
}
