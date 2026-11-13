import SwiftUI
import UIKit

/// The text of a note, a task's or a habit's, its draft's too: grows with the text, and a list goes on by itself
/// (`ListContinuation`, `rules.json` → `editing.listMarkers`). A `UITextView`, so the marker comes with the very
/// Return that asks for it: a SwiftUI field drops a text changed inside its own edit, and the marker could only follow later.
/// While typing, the text view is the source of the text: SwiftUI can hand back a value a keystroke old.
struct NoteTextField: View {
    @Environment(\.tokens) private var tokens
    @Environment(\.rules) private var rules
    @Environment(\.isEnabled) private var isEnabled
    let placeholder: LocalizedStringKey
    @Binding var text: String

    var body: some View {
        NoteTextView(text: $text, font: tokens.uiFont(.rowTitle), color: tokens.uiColor(.primaryText),
                     markers: rules.editing.listMarkers, isEditable: isEnabled)
            .overlay(alignment: .topLeading) {
                if text.isEmpty {
                    Text(placeholder)
                        .font(tokens.font(.rowTitle))
                        .foregroundStyle(tokens.color(.tertiaryText))
                        .allowsHitTesting(false)
                        .accessibilityHidden(true)
                }
            }
    }
}

private struct NoteTextView: UIViewRepresentable {
    @Binding var text: String
    let font: UIFont
    let color: UIColor
    let markers: [String]
    let isEditable: Bool

    func makeUIView(context: Context) -> UITextView {
        let view = UITextView()
        view.delegate = context.coordinator
        view.isScrollEnabled = false
        view.backgroundColor = .clear
        view.textContainerInset = .zero
        view.textContainer.lineFragmentPadding = 0
        view.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        view.font = font
        view.textColor = color
        view.text = text
        return view
    }

    /// Only what changed is set: assigning the font or the text again while typing would move the cursor.
    func updateUIView(_ view: UITextView, context: Context) {
        context.coordinator.parent = self
        if view.font != font { view.font = font; view.invalidateIntrinsicContentSize() }
        if view.textColor != color { view.textColor = color }
        if view.isEditable != isEditable { view.isEditable = isEditable }
        if view.text != text, !view.isFirstResponder, view.markedTextRange == nil {
            view.text = text
            view.invalidateIntrinsicContentSize()
        }
    }

    func sizeThatFits(_ proposal: ProposedViewSize, uiView: UITextView, context: Context) -> CGSize? {
        guard let width = proposal.width, width.isFinite else { return nil }
        let fitting = uiView.sizeThatFits(CGSize(width: width, height: .greatestFiniteMagnitude))
        return CGSize(width: width, height: ceil(fitting.height))
    }

    func makeCoordinator() -> Coordinator { Coordinator(parent: self) }

    final class Coordinator: NSObject, UITextViewDelegate {
        var parent: NoteTextView

        init(parent: NoteTextView) { self.parent = parent }

        func textView(_ textView: UITextView, shouldChangeTextIn range: NSRange, replacementText typed: String) -> Bool {
            guard textView.markedTextRange == nil,
                  let edit = ListContinuation.edit(in: textView.text, replacing: range, with: typed, markers: parent.markers)
            else { return true }
            textView.text = edit.text
            textView.selectedRange = NSRange(location: edit.utf16Cursor, length: 0)
            changed(textView)
            return false
        }

        func textViewDidChange(_ textView: UITextView) { changed(textView) }

        private func changed(_ textView: UITextView) {
            parent.text = textView.text
            textView.invalidateIntrinsicContentSize()
        }
    }
}
