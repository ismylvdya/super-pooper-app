import SwiftUI
import UIKit

/// A menu item's label from the action registry. An action with a color in `actions.json` gets it on its icon, drawn
/// as a colored picture since menus repaint plain symbols in the label color, and on its title where the
/// system lets it. `markIcon`: a habit mark image instead of the action's symbol.
struct ActionLabel: View {
    @Environment(\.tokens) private var tokens
    @Environment(\.icons) private var icons
    let action: ActionDefinition
    var markIcon: Icon?

    var body: some View {
        // A destructive action (Delete) is red on its icon too: the menu leaves a plain symbol black.
        let token = action.color.flatMap(ColorToken.init(rawValue:)) ?? (action.destructive ? .destructive : nil)
        let tint = token.map { tokens.uiColor($0) }
        Label {
            if let tint { Text(LocalizedStringKey(action.title)).foregroundStyle(Color(uiColor: tint)) } else { Text(LocalizedStringKey(action.title)) }
        } icon: {
            if let image = image(tint: tint) {
                Image(uiImage: image)
            } else if let markIcon {
                Image(icons[markIcon]).renderingMode(.template)
            } else {
                Image(systemName: action.icon)
            }
        }
    }

    private func image(tint: UIColor?) -> UIImage? {
        guard let tint else { return nil }
        let base = markIcon.flatMap { UIImage(named: icons[$0]) } ?? UIImage(systemName: action.icon)
        return base?.withTintColor(tint, renderingMode: .alwaysOriginal)
    }
}
