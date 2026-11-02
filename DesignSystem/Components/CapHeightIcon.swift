import SwiftUI
import UIKit

/// An icon from `icons.json` whose ink is exactly as tall as a capital letter of `font` (a bell after a line of text), cut
/// to its drawing so no room of the symbol's own box adds to it; tinted by the foreground style.
struct CapHeightIcon: View {
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
        let extent = tokens.uiFont(font).capHeight
        if let image = TemplateGlyph.image(icons[icon], extent: extent, along: .vertical, scale: scale)
            ?? TemplateGlyph.symbol(icons[icon], extent: extent, along: .vertical, scale: scale) {
            Image(uiImage: image)
        } else {
            Image(systemName: icons[icon])
        }
    }
}
