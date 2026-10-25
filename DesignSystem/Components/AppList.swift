import SwiftUI

extension View {
    /// A system List on the app's screen background instead of the grouped grey.
    func appList() -> some View {
        modifier(AppList())
    }
}

private struct AppList: ViewModifier {
    @Environment(\.tokens) private var tokens

    func body(content: Content) -> some View {
        content
            .scrollContentBackground(.hidden)
            .background(tokens.color(.screenBackground))
    }
}
