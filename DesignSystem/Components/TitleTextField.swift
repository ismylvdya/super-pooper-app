import SwiftUI

/// A note's name typed right in a page's title: centered, wrapping onto more lines, Return ends the editing (in a
/// field that wraps, Return would insert a newline). The new-note page and the task page title use it.
struct TitleTextField: View {
    let placeholder: LocalizedStringKey
    @Binding var text: String
    let color: Color
    var isFocused: FocusState<Bool>.Binding

    var body: some View {
        TextField(placeholder, text: $text, axis: .vertical)
            .multilineTextAlignment(.center)
            .foregroundStyle(color)
            .submitLabel(.done)
            .focused(isFocused)
            .onChange(of: text) { _, value in
                guard value.contains("\n") else { return }
                text = value.replacingOccurrences(of: "\n", with: "")
                isFocused.wrappedValue = false
            }
            .accessibilityIdentifier("taskPage.name")
    }
}
