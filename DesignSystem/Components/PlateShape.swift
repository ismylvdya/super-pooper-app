import SwiftUI

/// A rounded plate whose corners are never rounder than half its shorter side. A row's radius token is meant for a
/// row of normal height; on a short timeline slot or a lifted row it would round past the middle (a lens instead of
/// a plate). Every plate of a row — pool, timeline, widget, grouped lists and their lifted previews — uses it.
///
/// Inset (a `strokeBorder` drawn inside the plate), its corners are concentric with the plate's own: the radius shrinks by
/// as much as the edges move in. Circular corners: a continuous one bends by the plate's height, so a row and the taller
/// shared plate around it would part at the same radius and the plate would cut the row's outline.
struct PlateShape: InsettableShape {
    var cornerRadius: CGFloat
    var inset: CGFloat = 0

    func path(in rect: CGRect) -> Path {
        let outer = min(cornerRadius, rect.height / 2, rect.width / 2)
        return RoundedRectangle(cornerRadius: max(outer - inset, 0), style: .circular).path(in: rect.insetBy(dx: inset, dy: inset))
    }

    func inset(by amount: CGFloat) -> PlateShape {
        PlateShape(cornerRadius: cornerRadius, inset: inset + amount)
    }
}
