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
    @Environment(\.icons) private var icons
    @Binding var isSearching: Bool
    var accessibilityID = "page.search"

    var body: some View {
        Button { isSearching = true } label: { Image(systemName: icons[.search]) }
            .accessibilityLabel(Text("search.title"))
            .accessibilityIdentifier(accessibilityID)
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
