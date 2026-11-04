import SwiftUI

/// The name of a new task or habit, typed right in the page title with the cursor already in it; Return closes the
/// keyboard and tells the page (`onReturn`), which saves the note. A name a note cannot take is shown in the problem
/// color with what to change. A date found in the name (`suggestion`) is blue; a tap on it, with some room above and
/// below so it is easy to hit, hands it to the page (`onAccept`).
struct NewNoteNameField: View {
    @Environment(\.tokens) private var tokens
    @Environment(\.icons) private var icons
    let placeholder: LocalizedStringKey
    @Binding var name: String
    let problem: NoteNameProblem?
    var suggestion: DetectedDate?
    var onAccept: (DetectedDate) -> Void = { _ in }
    let onReturn: () -> Void
    @State private var suggestionFrames: [CGRect] = []
    /// Counts the times the page changed the name itself (a date taken out of it).
    @State private var replacements = 0

    var body: some View {
        VStack(spacing: tokens.space(.titleDetailGap)) {
            HighlightingTitleField(text: $name, replacement: replacements, font: tokens.uiFont(.pageTitle),
                                   color: tokens.uiColor(problem == nil ? .primaryText : .problem),
                                   highlights: highlights, highlightColor: tokens.uiColor(.detectedDate),
                                   onReturn: onReturn, onHighlightFrames: { suggestionFrames = $0 },
                                   focusDelay: tokens.duration(.keyboardAfterPush))
                .overlay {
                    if name.isEmpty {
                        Text(placeholder)
                            .foregroundStyle(tokens.color(.tertiaryText))
                            .allowsHitTesting(false)
                            .accessibilityIdentifier("taskPage.name.placeholder")
                    }
                }
                .overlay(alignment: .topLeading) { suggestionTargets }
            if let problem {
                Label(NoteNameProblemText.describe(problem, name: name), systemImage: icons[.problem])
                    .font(tokens.font(.hint))
                    .foregroundStyle(tokens.color(.problem))
                    .accessibilityIdentifier("taskPage.name.problem")
            }
        }
    }

    private var highlights: [NSRange] {
        suggestion?.ranges.filter { $0.upperBound <= name.endIndex }.map { NSRange($0, in: name) } ?? []
    }

    /// A clear button over each line of the blue words, taller than the line by the tap room.
    @ViewBuilder private var suggestionTargets: some View {
        if let suggestion, !highlights.isEmpty {
            let room = tokens.size(.detectedDateTapRoom)
            let words = suggestion.ranges.map { String(name[$0]) }.joined(separator: " ")
            ForEach(Array(suggestionFrames.enumerated()), id: \.offset) { _, frame in
                Button {
                    onAccept(suggestion)
                    replacements += 1
                } label: { Color.clear.contentShape(Rectangle()) }
                    .frame(width: frame.width, height: frame.height + 2 * room)
                    .offset(x: frame.minX, y: frame.minY - room)
                    .accessibilityLabel(words)
                    .accessibilityIdentifier("newItem.detectedDate")
            }
        }
    }
}
