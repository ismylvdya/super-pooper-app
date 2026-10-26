import SwiftUI

/// The plate behind one row of a group laid out as rows of a list: rounded only at the group's top and bottom,
/// so the rows of a group read as one plate.
struct GroupRowBackground: View {
    @Environment(\.tokens) private var tokens
    let isFirst: Bool
    let isLast: Bool

    var body: some View {
        Self.shape(isFirst: isFirst, isLast: isLast, radius: tokens.radius(.plate)).fill(tokens.color(.plateBackground))
    }

    /// The row's piece of the group's rounded plate.
    static func shape(isFirst: Bool, isLast: Bool, radius: CGFloat) -> UnevenRoundedRectangle {
        let top = isFirst ? radius : 0
        let bottom = isLast ? radius : 0
        return UnevenRoundedRectangle(topLeadingRadius: top, bottomLeadingRadius: bottom, bottomTrailingRadius: bottom,
                                      topTrailingRadius: top, style: .continuous)
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
