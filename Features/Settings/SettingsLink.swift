import SwiftUI

/// A plate row that pushes a page.
struct SettingsLink: View {
    @Environment(\.tokens) private var tokens
    @Environment(\.icons) private var icons
    let route: Route
    let icon: Icon
    let title: LocalizedStringKey
    var value: String?

    var body: some View {
        NavigationLink(value: route) {
            PlateRow(icon: icon, title: title) {
                if let value { Text(verbatim: value).foregroundStyle(tokens.color(.secondaryText)) }
                Image(systemName: icons[.chevron]).foregroundStyle(tokens.color(.tertiaryText))
            }
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("settings.link.\(String(describing: route))")
    }
}
