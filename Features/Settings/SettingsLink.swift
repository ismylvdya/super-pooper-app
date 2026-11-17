import SwiftUI

/// A plate row that pushes a page.
struct SettingsLink: View {
    let route: Route
    let icon: Icon
    let title: LocalizedStringKey
    var value: String?
    /// Drawn in the icon's place (`PlateRow.iconImage`).
    var iconImage: Image?

    var body: some View {
        NavigationLink(value: route) {
            PlateRow(icon: icon, title: title) { DisclosureAccessory(value: value) }
                .showingIcon(iconImage)
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("settings.link.\(String(describing: route))")
    }
}
