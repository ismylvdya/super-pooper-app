import SwiftUI

extension View {
    /// A setting that belongs to the switch above it, in a form: indented like a child `PlateRow`.
    func childRow() -> some View {
        modifier(ChildRow())
    }
}

private struct ChildRow: ViewModifier {
    @Environment(\.tokens) private var tokens

    func body(content: Content) -> some View {
        content.padding(.leading, tokens.space(.childIndent))
    }
}
