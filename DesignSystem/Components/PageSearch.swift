import SwiftUI

extension View {
    /// The page's search field, opened from `SearchBarButton` in the bar (as on Today): no field hides above the page
    /// to be pulled down. Closing it clears the query.
    func pageSearch(query: Binding<String>, isSearching: Binding<Bool>, prompt: LocalizedStringKey) -> some View {
        modifier(PageSearch(query: query, isSearching: isSearching, prompt: prompt))
    }
}

/// The search button of a page's bar; it stands to the right of the page's other buttons, in the same bubble.
struct SearchBarButton: View {
    @Binding var isSearching: Bool
    var accessibilityID = "page.search"

    var body: some View {
        Button { isSearching = true } label: { SearchGlyph() }
            .accessibilityLabel(Text("search.title"))
            .accessibilityIdentifier(accessibilityID)
    }
}

/// The magnifier of every search button: a little above the middle of its bubble, where it looks centered.
struct SearchGlyph: View {
    @Environment(\.tokens) private var tokens
    @Environment(\.icons) private var icons

    var body: some View {
        Image(systemName: icons[.search]).offset(y: -tokens.bar(.searchGlyphLift))
    }
}

private struct PageSearch: ViewModifier {
    @Binding var query: String
    @Binding var isSearching: Bool
    let prompt: LocalizedStringKey

    func body(content: Content) -> some View {
        if isSearching {
            content.searchable(text: $query, isPresented: $isSearching, placement: .navigationBarDrawer(displayMode: .always),
                               prompt: Text(prompt))
        } else {
            content.onAppear { query = "" }
        }
    }
}
