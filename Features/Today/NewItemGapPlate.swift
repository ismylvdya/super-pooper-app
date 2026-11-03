import SwiftUI

/// The room a "+" dragged over the pool makes: as tall as a one-line plate, with nothing in it, as a dragged task's gap.
struct NewItemGapPlate: View {
    @Environment(\.tokens) private var tokens

    var body: some View {
        Text(verbatim: " ")
            .font(tokens.font(.taskTitle))
            .frame(maxWidth: .infinity, alignment: .leading)
            .poolRowPlate(.own, isDone: false)
            .dropGap()
    }
}
