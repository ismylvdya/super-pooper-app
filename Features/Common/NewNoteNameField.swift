import SwiftUI

/// The name of a new task or habit, typed right in the page title with the cursor already in it; Return closes the
/// keyboard and keeps the name. A name a note cannot take is shown in the problem color with what to change.
struct NewNoteNameField: View {
    @Environment(\.tokens) private var tokens
    @Environment(\.icons) private var icons
    let placeholder: LocalizedStringKey
    @Binding var name: String
    let problem: NoteNameProblem?
    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(spacing: tokens.space(.titleDetailGap)) {
            TitleTextField(placeholder: placeholder, text: $name,
                           color: problem == nil ? tokens.color(.primaryText) : tokens.color(.problem), isFocused: $isFocused)
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
