import SwiftUI

/// The text of a note, a task's or a habit's, its draft's too: grows with the text, and a list goes on by itself
/// (`ListContinuation`, `rules.json` → `editing.listMarkers`).
struct NoteTextField: View {
    @Environment(\.tokens) private var tokens
    @Environment(\.rules) private var rules
    let placeholder: LocalizedStringKey
    @Binding var text: String

    var body: some View {
        TextField(placeholder, text: Binding(get: { text }, set: change), axis: .vertical)
            .font(tokens.font(.rowTitle))
    }

    private func change(_ new: String) {
        let edit = ListContinuation.edit(from: text, to: new, markers: rules.editing.listMarkers)
        text = new
        guard let edit else { return }
        // The field takes a text changed inside its own edit as its own and drops it: the marker comes a moment later.
        DispatchQueue.main.async { text = edit.text }
    }
}
