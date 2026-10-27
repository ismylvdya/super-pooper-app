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
            // The chips on the right keep the same distance from the plate's top, bottom and right edge.
            .padding(.vertical, tokens.space(.rowVertical) / 2)
            .padding(.leading, tokens.space(.plateInner) / 2)
            .padding(.trailing, tokens.space(.rowVertical) / 2)
            .environment(\.bareTitleInset, tokens.space(.plateInner) / 2 - tokens.space(.rowVertical) / 2)
            .background(tokens.color(.plateBackground), in: RoundedRectangle(cornerRadius: tokens.rowPlateRadius, style: .continuous))
            .opacity(isDone ? tokens.opacity(.past) : 1)
    }
}
