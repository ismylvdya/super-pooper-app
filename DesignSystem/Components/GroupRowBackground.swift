import SwiftUI

/// The plate behind one row of a group laid out as rows of a list: rounded only at the group's top and bottom,
/// so the rows of a group read as one plate.
struct GroupRowBackground: View {
    @Environment(\.tokens) private var tokens
    let isFirst: Bool
    let isLast: Bool

    var body: some View {
        let top = isFirst ? tokens.radius(.plate) : 0
        let bottom = isLast ? tokens.radius(.plate) : 0
        UnevenRoundedRectangle(topLeadingRadius: top, bottomLeadingRadius: bottom, bottomTrailingRadius: bottom,
                               topTrailingRadius: top, style: .continuous)
            .fill(tokens.color(.plateBackground))
    }
}

extension View {
    /// A row of a group: its piece of the group's plate, with no separator above the first row or below the last.
    func groupRow(isFirst: Bool, isLast: Bool) -> some View {
        listRowBackground(GroupRowBackground(isFirst: isFirst, isLast: isLast))
            .listRowSeparator(isFirst ? .hidden : .automatic, edges: .top)
            .listRowSeparator(isLast ? .hidden : .automatic, edges: .bottom)
    }
}
