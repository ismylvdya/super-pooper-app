import SwiftUI

/// A pool row on its plate with its high-priority tint.
struct PlatedPoolRow<Row: View>: View {
    @Environment(\.tokens) private var tokens
    let item: DayItem
    let plate: PoolRowPlate
    /// Extra height under the content (pool rows of long tasks).
    var minimumHeight: CGFloat = 0
    @ViewBuilder let row: Row

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            row
            // Only for a long task: in a widget a spacer would take all the room there is.
            if minimumHeight > 0 { Spacer(minLength: minimumHeight) }
        }
        .poolRowPlate(plate, isDone: item.isFinished, tint: tokens.plateTint(for: item.task))
    }
}
