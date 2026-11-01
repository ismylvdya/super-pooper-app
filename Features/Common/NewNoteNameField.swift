import SwiftUI

/// The name of a new task or habit, typed right in the page title with the cursor already in it; Return closes the
/// keyboard and tells the page (`onReturn`), which saves the note. A name a note cannot take is shown in the problem
/// color with what to change.
struct NewNoteNameField: View {
    @Environment(\.tokens) private var tokens
    @Environment(\.icons) private var icons
    let placeholder: LocalizedStringKey
    @Binding var name: String
    let problem: NoteNameProblem?
    let onReturn: () -> Void
    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(spacing: tokens.space(.titleDetailGap)) {
            TitleTextField(placeholder: placeholder, text: $name,
                           color: problem == nil ? tokens.color(.primaryText) : tokens.color(.problem), isFocused: $isFocused,
                           onReturn: onReturn)
            if let problem {
                Label(NoteNameProblemText.describe(problem, name: name), systemImage: icons[.problem])
                    .font(tokens.font(.hint))
                    .foregroundStyle(tokens.color(.problem))
                    .accessibilityIdentifier("taskPage.name.problem")
            }
        }
        .task { isFocused = true }
    }
}
