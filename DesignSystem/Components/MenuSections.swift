import SwiftUI

/// A menu's frequent items on top and the rarer ones in a section under them, split by the system's divider; without
/// rarer items, one plain list.
struct MenuSections<Item, Row: View>: View {
    let frequent: [Item]
    let more: [Item]
    @ViewBuilder let row: (Item) -> Row

    var body: some View {
        Section { ForEach(frequent.indices, id: \.self) { row(frequent[$0]) } }
        if !more.isEmpty {
            Section { ForEach(more.indices, id: \.self) { row(more[$0]) } }
        }
    }
}
