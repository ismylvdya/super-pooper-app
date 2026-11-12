import SwiftUI

/// The slider at the top of a note's page that says what it is (`NoteKind`), in one order, from the plainest to the most
/// kept track of: a new note's page offers all three, a habit's or repeatable task's page the last two.
struct NoteKindPicker: View {
    static let order: [NoteKind] = [.task, .repeatable, .habit]
    let kinds: [NoteKind]
    @Binding var selection: NoteKind

    var body: some View {
        Picker("newItem.kind", selection: $selection) {
            ForEach(Self.order.filter(kinds.contains), id: \.self) { Text(verbatim: L10n.string("newItem.kind." + $0.rawValue)).tag($0) }
        }
        .pickerStyle(.segmented)
        .accessibilityIdentifier("noteKind")
    }
}
