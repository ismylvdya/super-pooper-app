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
            TextField(placeholder, text: $name, axis: .vertical)
                .multilineTextAlignment(.center)
                .foregroundStyle(problem == nil ? tokens.color(.primaryText) : tokens.color(.problem))
                .submitLabel(.done)
                .focused($isFocused)
                .onChange(of: name) { _, value in
                    // Return in a vertical field inserts a newline: it means "done".
                    guard value.contains("\n") else { return }
                    name = value.replacingOccurrences(of: "\n", with: "")
                    isFocused = false
                }
                .accessibilityIdentifier("taskPage.name")
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
