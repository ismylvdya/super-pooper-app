import SwiftUI

extension View {
    /// A row of a `Plate` that covers its whole piece of the plate — over the plate's inner margins and half the gaps to
    /// the rows beside it — with the plate's color, as a habit of a routine in the pool; a drag (`onDrag`) lifts that
    /// piece as a rounded plate of its own. Among the plate's rows it keeps its usual place.
    func plateBleedRow(onDrag: @escaping () -> NSItemProvider) -> some View {
        modifier(PlateBleedRow(onDrag: onDrag))
    }
}

private struct PlateBleedRow: ViewModifier {
    @Environment(\.tokens) private var tokens
    let onDrag: () -> NSItemProvider

    /// The plate's own inner margin and the gap between its rows (`Plate`).
    func body(content: Content) -> some View {
        let inner = tokens.space(.plateInner)
        let halfGap = tokens.space(.plateRowGap) / 2
        content
            .padding(.horizontal, inner)
            .padding(.vertical, halfGap)
            .plate(.group)
            .plateLift(.group, for: .dragPreview)
            .onDrag(onDrag)
            .padding(.horizontal, -inner)
            .padding(.vertical, -halfGap)
    }
}
