import SwiftUI

/// The bar's search button of a page: opens the search page over what `scope` names. Today, Lists and the morning review
/// page all have this one.
struct OpenSearchButton: View {
    @Environment(Router.self) private var router
    @Environment(\.tokens) private var tokens
    let scope: SearchScope
    let accessibilityID: String

    var body: some View {
        Button { router.open(.search(scope)) } label: { SearchGlyph() }
            .tint(tokens.color(.accent))
            .accessibilityLabel(Text("search.title"))
            .accessibilityIdentifier(accessibilityID)
    }
}
