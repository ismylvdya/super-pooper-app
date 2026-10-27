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

extension View {
    /// What a long press lifts from a grouped row: the row at its own size as a whole rounded plate (the group's
    /// corners of a first or last row turn into the full plate's), for the context menu and for dragging. The row
    /// must fill its list cell, so nothing around it (screen margins, cell insets) is lifted with it.
    func liftedPlate() -> some View {
        modifier(LiftedPlate())
    }
}

private struct LiftedPlate: ViewModifier {
    @Environment(\.tokens) private var tokens

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: tokens.radius(.plate), style: .continuous)
        content
            .contentShape(.contextMenuPreview, shape)
            .contentShape(.dragPreview, shape)
    }
}
