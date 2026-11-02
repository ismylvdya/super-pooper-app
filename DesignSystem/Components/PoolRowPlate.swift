import SwiftUI

/// How a pool row stands on a plate: a task on a plate of its own, or a habit of a routine on its piece of the routine's
/// shared plate (`PoolSegmentView`). The insets are the same, so the rows of a routine stand as far apart as rows on
/// plates of their own. A routine holds only open habits, so its pieces never fade as done.
enum PoolRowPlate {
    case own
    case piece

    /// The shape of a tint over the row (high priority): the row's own rounded plate, also on a routine's piece.
    var tintCorners: PlateCorners { .row }
}

extension View {
    func poolRowPlate(_ plate: PoolRowPlate, isDone: Bool, tint: Color? = nil) -> some View {
        modifier(PoolRowPlateFill(plate: plate, isDone: isDone, tint: tint))
    }
}

private struct PoolRowPlateFill: ViewModifier {
    @Environment(\.tokens) private var tokens
    let plate: PoolRowPlate
    let isDone: Bool
    let tint: Color?

    func body(content: Content) -> some View {
        switch plate {
        case .own: content.taskPlate(isDone: isDone, tint: tint)
        case .piece:
            content.rowPlatePadding()
                .background { if let tint { tokens.plateShape(plate.tintCorners).fill(tint) } }
                .plate(.piece)
        }
    }
}
