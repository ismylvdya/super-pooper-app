import SwiftUI
import UIKit

/// A name typed right in a new note's title, like `TitleTextField` (centred, wrapping, Return ends the editing), that
/// takes the keyboard by itself once the page has slid in (`focusDelay`). A `UITextView`, so the keyboard can wait for
/// the slide. While typing, the text view is the source of the text: SwiftUI can hand back a value a keystroke old, and
/// putting it into the view would move the cursor.
struct AutofocusTitleField: UIViewRepresentable {
    @Binding var text: String
    let font: UIFont
    let color: UIColor
    /// Return was pressed (the editing has ended).
    var onReturn: () -> Void = {}
    var focusDelay: TimeInterval = 0

    func makeUIView(context: Context) -> AutofocusTextView {
        let view = AutofocusTextView()
        view.focusDelay = focusDelay
        view.delegate = context.coordinator
        view.isScrollEnabled = false
        view.backgroundColor = .clear
        view.textAlignment = .center
        view.textContainerInset = .zero
        view.textContainer.lineFragmentPadding = 0
        view.returnKeyType = .done
        view.accessibilityIdentifier = "taskPage.name"
        view.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        view.text = text
        return view
    }

    /// Only what changed is set: assigning the font or the color again while typing would move the cursor.
    func updateUIView(_ view: AutofocusTextView, context: Context) {
        context.coordinator.parent = self
        if view.font != font { view.font = font; view.invalidateIntrinsicContentSize() }
        if view.textColor != color { view.textColor = color }
        if view.text != text, !view.isFirstResponder, view.markedTextRange == nil { view.text = text }
    }

    func sizeThatFits(_ proposal: ProposedViewSize, uiView: AutofocusTextView, context: Context) -> CGSize? {
        guard let width = proposal.width, width.isFinite else { return nil }
        let fitting = uiView.sizeThatFits(CGSize(width: width, height: .greatestFiniteMagnitude))
        return CGSize(width: width, height: ceil(fitting.height))
    }

    func makeCoordinator() -> Coordinator { Coordinator(parent: self) }

    final class Coordinator: NSObject, UITextViewDelegate {
        var parent: AutofocusTitleField

        init(parent: AutofocusTitleField) { self.parent = parent }

        func textView(_ textView: UITextView, shouldChangeTextIn range: NSRange, replacementText replacement: String) -> Bool {
            guard replacement.contains("\n") else { return true }
            textView.resignFirstResponder()
            parent.onReturn()
            return false
        }

        func textViewDidChange(_ textView: UITextView) {
            parent.text = textView.text
            textView.invalidateIntrinsicContentSize()
        }
    }
}

/// The text view of `AutofocusTitleField`: takes the keyboard when it first appears.
final class AutofocusTextView: UITextView {
    /// How long the keyboard waits after the field appears.
    var focusDelay: TimeInterval = 0
    private var hasAppeared = false

    override func didMoveToWindow() {
        super.didMoveToWindow()
        guard window != nil, !hasAppeared else { return }
        hasAppeared = true
        // After the page has slid in: raising the keyboard is slow the first time, and during the slide it would stall it.
        DispatchQueue.main.asyncAfter(deadline: .now() + focusDelay) { [weak self] in self?.becomeFirstResponder() }
    }
}
