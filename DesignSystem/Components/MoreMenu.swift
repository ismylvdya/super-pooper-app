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
