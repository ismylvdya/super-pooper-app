import SwiftUI

extension View {
    /// A system List on the app's screen background instead of the grouped grey; scrolled to the end, its last row
    /// clears the bars by `scrollEndRoom`.
    func appList() -> some View {
        modifier(AppList())
    }
}

private struct AppList: ViewModifier {
    @Environment(\.tokens) private var tokens

    func body(content: Content) -> some View {
        content
            .scrollContentBackground(.hidden)
            .contentMargins(.bottom, tokens.space(.scrollEndRoom), for: .scrollContent)
            .background(tokens.color(.screenBackground))
    }
}
