import SwiftUI

/// A rounded plate whose corners are never rounder than half its shorter side. A row's radius token is meant for a
/// row of normal height; on a short timeline slot or a lifted row it would round past the middle (a lens instead of
/// a plate). Every plate of a row — pool, timeline, widget, grouped lists and their lifted previews — uses it.
struct PlateShape: Shape {
    var cornerRadius: CGFloat

    func path(in rect: CGRect) -> Path {
        RoundedRectangle(cornerRadius: min(cornerRadius, rect.height / 2, rect.width / 2), style: .continuous).path(in: rect)
    }
}
