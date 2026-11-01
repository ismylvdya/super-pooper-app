import SwiftUI

/// How a pool row stands on a plate: a task on a plate of its own, or a habit of a routine on its piece of the routine's
/// shared plate (`PoolSegmentView`). The insets are the same, so the rows of a routine stand as far apart as rows on
/// plates of their own. A routine holds only open habits, so its pieces never fade as done.
enum PoolRowPlate {
    case own
    case piece
}

extension View {
    func poolRowPlate(_ plate: PoolRowPlate, isDone: Bool) -> some View {
        modifier(PoolRowPlateFill(plate: plate, isDone: isDone))
    }
}

private struct PoolRowPlateFill: ViewModifier {
    let plate: PoolRowPlate
    let isDone: Bool

    func body(content: Content) -> some View {
        switch plate {
        case .own: content.taskPlate(isDone: isDone)
        case .piece: content.rowPlatePadding().plate(.piece)
        }
    }
}
