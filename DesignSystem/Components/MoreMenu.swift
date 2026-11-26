import SwiftUI

/// The bar's "…": a system menu of rarer things to do (a note's actions, Select mode's, a list's). Every "…" of the app
/// is this one, so they look and read the same.
struct MoreMenu<Content: View>: View {
    @Environment(\.tokens) private var tokens
    @Environment(\.icons) private var icons
    var accessibilityID = "more"
    @ViewBuilder let content: () -> Content

    var body: some View {
        Menu { content() } label: { Image(systemName: icons[.more]) }
            .tint(tokens.color(.accent))
            .accessibilityLabel(Text("common.more"))
            .accessibilityIdentifier(accessibilityID)
    }
}

/// A menu keeps template icons bright on disabled rows. Give the unavailable icon the same dim color as its title.
struct AvailabilityMenuButton: View {
    @Environment(\.icons) private var icons
    @Environment(\.tokens) private var tokens
    let title: LocalizedStringKey
    let icon: Icon
    let isEnabled: Bool
    let action: () async -> Void

    var body: some View {
        Button { Task { await action() } } label: {
            Label {
                Text(title)
            } icon: {
                if isEnabled {
                    Image(systemName: icons[icon])
                } else if let dim = UIImage(systemName: icons[icon])?.withTintColor(tokens.uiColor(.tertiaryText), renderingMode: .alwaysOriginal) {
                    Image(uiImage: dim)
                }
            }
        }
        .disabled(!isEnabled)
    }
}
