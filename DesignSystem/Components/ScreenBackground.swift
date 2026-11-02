import SwiftUI

extension View {
    /// The screen's background color behind a page, reaching under the bars and the keyboard. Every page sets it this
    /// way: what lies behind the keyboard shows past its rounded corners on iOS 26, and a background that stops above the
    /// keyboard leaves the system's own white there.
    func screenBackground() -> some View {
        modifier(ScreenBackground())
    }
}

private struct ScreenBackground: ViewModifier {
    @Environment(\.tokens) private var tokens

    func body(content: Content) -> some View {
        content.background { tokens.color(.screenBackground).ignoresSafeArea() }
    }
}
