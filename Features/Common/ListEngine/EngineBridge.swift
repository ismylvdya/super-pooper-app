import ListEngineChumbulev
import SwiftUI
import UIKit

/// What the app hands the list engine (ListEngineChumbulev): its colors, its icons and its look (`list-theme.json`).
extension ListTheme {
    /// Every list's look, from the app's own theme file.
    static let app = ListTheme.bundled("list-theme")
}

extension ThemeColor {
    /// An app color (a token, the settings' own) as the engine takes it: as it is in the light and in the dark.
    init(_ color: UIColor) {
        self.init(light: Self.hex(color.resolvedColor(with: UITraitCollection(userInterfaceStyle: .light))),
                  dark: Self.hex(color.resolvedColor(with: UITraitCollection(userInterfaceStyle: .dark))))
    }

    init(_ color: Color) {
        self.init(UIColor(color))
    }

    private static func hex(_ color: UIColor) -> String {
        var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
        color.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        let byte = { (value: CGFloat) in Int((min(max(value, 0), 1) * 255).rounded()) }
        return String(format: "#%02X%02X%02X%02X", byte(red), byte(green), byte(blue), byte(alpha))
    }
}

extension ListIcon {
    /// An app icon by its name (`icons.json`): an image of the app's assets, or an SF Symbol.
    static func app(_ name: String) -> ListIcon {
        UIImage(named: name) != nil ? .picture(name) : .symbol(name)
    }
}
