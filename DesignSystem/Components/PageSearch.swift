import SwiftUI

extension View {
    /// The page's search field, opened from the bar's "…" or a hold of its title (`PageMoreMenu`, `searchOnTitleHold`): no field hides above the page
    /// to be pulled down. Closing it clears the query.
    func pageSearch(query: Binding<String>, isSearching: Binding<Bool>, prompt: LocalizedStringKey) -> some View {
        modifier(PageSearch(query: query, isSearching: isSearching, prompt: prompt))
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
