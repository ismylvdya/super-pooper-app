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

    var body: some View {
        VStack(spacing: tokens.space(.titleDetailGap)) {
            AutofocusTitleField(text: $name, font: tokens.uiFont(.pageTitle),
                                color: tokens.uiColor(problem == nil ? .primaryText : .problem),
                                onReturn: onReturn, focusDelay: tokens.duration(.keyboardAfterPush))
                .overlay {
                    if name.isEmpty {
                        Text(placeholder)
                            .foregroundStyle(tokens.color(.tertiaryText))
                            .allowsHitTesting(false)
                            .accessibilityIdentifier("taskPage.name.placeholder")
                    }
                }
            if let problem {
                Label(NoteNameProblemText.describe(problem, name: name), systemImage: icons[.problem])
                    .font(tokens.font(.hint))
                    .foregroundStyle(tokens.color(.problem))
                    .accessibilityIdentifier("taskPage.name.problem")
            }
        }
    }
}
