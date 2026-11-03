import SwiftUI

/// The room a "+" dragged over the pool makes: an empty one-line plate, faint as a dragged task's gap.
struct NewItemGapPlate: View {
    @Environment(\.tokens) private var tokens

    var body: some View {
        Text(verbatim: " ")
            .font(tokens.font(.taskTitle))
            .frame(maxWidth: .infinity, alignment: .leading)
            .poolRowPlate(.own, isDone: false)
            .dropGhost()
    }
}
