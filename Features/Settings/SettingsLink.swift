import SwiftUI

/// A plate row that pushes a page.
struct SettingsLink: View {
    let route: Route
    let icon: Icon
    let title: LocalizedStringKey
    var value: String?

    var body: some View {
        NavigationLink(value: route) {
            PlateRow(icon: icon, title: title) { DisclosureAccessory(value: value) }
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("settings.link.\(String(describing: route))")
    }
}
