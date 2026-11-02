import SwiftUI

extension View {
    /// The plate a task row sits on (pool, widgets); a done row fades with its plate to the "past" opacity. `tint` lies
    /// over the plate (`DesignTokens.plateTint`).
    func taskPlate(isDone: Bool = false, tint: Color? = nil) -> some View {
        modifier(TaskPlate(isDone: isDone, tint: tint))
    }

    /// The insets of a row on its plate, the same whether the plate is its own or shared (a routine): the chips on the
    /// right keep the same distance from the plate's top, bottom and right edge.
    func rowPlatePadding() -> some View {
        modifier(RowPlatePadding())
    }
}

private struct RowPlatePadding: ViewModifier {
    @Environment(\.tokens) private var tokens

    func body(content: Content) -> some View {
        content
            .padding(.vertical, tokens.space(.rowVertical) / 2)
            .padding(.leading, tokens.space(.plateInner) / 2)
            .padding(.trailing, tokens.rowPlateTrailingInset)
            .environment(\.plateTrailingInset, tokens.rowPlateTrailingInset)
    }
}

private struct TaskPlate: ViewModifier {
    @Environment(\.tokens) private var tokens
    let isDone: Bool
    let tint: Color?

    func body(content: Content) -> some View {
        content
            .rowPlatePadding()
            .plate(.row, tint: tint)
            .opacity(isDone ? tokens.opacity(.past) : 1)
    }
}
