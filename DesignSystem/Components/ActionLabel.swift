import SwiftUI
import UIKit

/// A menu item's label from the action registry. An action with a color in `actions.json` gets it on its icon, drawn
/// as a colored picture since menus repaint plain symbols in the label color, and on its title where the
/// system lets it. `markIcon`: a habit mark image instead of the action's symbol.
struct ActionLabel: View {
    @Environment(\.tokens) private var tokens
    @Environment(\.icons) private var icons
    @Environment(\.displayScale) private var scale
    let action: ActionDefinition
    var markIcon: Icon?

    var body: some View {
        // A destructive action (Delete) is red on its icon too: the menu leaves a plain symbol black.
        let token = action.color.flatMap(ColorToken.init(rawValue:)) ?? (action.destructive ? .destructive : nil)
        let tint = token.map { tokens.uiColor($0) }
        Label {
            if let tint { Text(LocalizedStringKey(action.title)).foregroundStyle(Color(uiColor: tint)) } else { Text(LocalizedStringKey(action.title)) }
        } icon: {
            let name = markIcon.map { icons[$0] } ?? action.icon
            if let image = TemplateGlyph.menuImage(name, extent: tokens.size(.menuIcon), scale: scale) {
                Image(uiImage: styled(image, tint: tint))
            }
        }
    }

    private func styled(_ image: UIImage, tint: UIColor?) -> UIImage {
        if markIcon == .habitMarkOpen {
            let muted = (tint ?? .label).withAlphaComponent(tokens.opacity(.habitOpenRing))
            return image.withTintColor(muted, renderingMode: .alwaysOriginal)
        }
        return tint.map { image.withTintColor($0, renderingMode: .alwaysOriginal) } ?? image
    }
}
