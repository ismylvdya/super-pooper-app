import SwiftUI

extension View {
    /// The plate a task row sits on (pool, widgets); a done row fades with its plate to the "past" opacity.
    func taskPlate(isDone: Bool = false) -> some View {
        modifier(TaskPlate(isDone: isDone))
    }
}

private struct TaskPlate: ViewModifier {
    @Environment(\.tokens) private var tokens
    let isDone: Bool

    func body(content: Content) -> some View {
        content
            .padding(.vertical, tokens.space(.rowVertical) / 2)
            .padding(.horizontal, tokens.space(.plateInner) / 2)
            .background(tokens.color(.plateBackground), in: RoundedRectangle(cornerRadius: tokens.radius(.poolRow), style: .continuous))
            .opacity(isDone ? tokens.opacity(.past) : 1)
    }
}
