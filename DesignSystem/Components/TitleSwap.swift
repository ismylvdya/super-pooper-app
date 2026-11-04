import SwiftUI

extension View {
    /// The one way a title in the bar changes (the day's name, a list's title): the old text fades into the new one in
    /// place and in a moment (`duration.titleSwap`). It takes no part in the animation of whatever changed it (pages
    /// sliding, a spring), which would carry it sideways.
    func titleSwap<Value: Hashable>(_ value: Value) -> some View {
        modifier(TitleSwap(value: value))
    }
}

private struct TitleSwap<Value: Hashable>: ViewModifier {
    @Environment(\.tokens) private var tokens
    let value: Value

    func body(content: Content) -> some View {
        content
            .contentTransition(.opacity)
            .animation(.easeInOut(duration: tokens.duration(.titleSwap)), value: value)
    }
}
