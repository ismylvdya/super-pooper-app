import SwiftUI
import UIKit

/// A name typed right in a page's title, like `TitleTextField` (centred, wrapping, Return ends the editing), whose
/// `highlights` are drawn in `highlightColor` inside the text. A SwiftUI text field cannot colour part of its text,
/// so this one is a `UITextView`. It reports where the highlighted words stand (`onHighlightFrames`, in its own space,
/// one rect per line a highlight covers) so the page can lay a tap target over them.
/// While typing, the text view is the source of the text: SwiftUI can hand back a value a keystroke old, and putting
/// it into the view would move the cursor. The owner puts its own text in by changing `replacement`.
struct HighlightingTitleField: UIViewRepresentable {
    @Binding var text: String
    /// Changed by the owner when it sets `text` itself (not from typing).
    var replacement = 0
    let font: UIFont
    let color: UIColor
    let highlights: [NSRange]
    let highlightColor: UIColor
    /// Return was pressed (the editing has ended).
    var onReturn: () -> Void = {}
    var onHighlightFrames: ([CGRect]) -> Void = { _ in }
    var focusDelay: TimeInterval = 0

    func makeUIView(context: Context) -> TitleTextView {
        let view = TitleTextView()
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
        context.coordinator.replacement = replacement
        return view
    }

    func updateUIView(_ view: TitleTextView, context: Context) {
        context.coordinator.parent = self
        view.onLayout = { [weak view] in
            guard let view else { return }
            context.coordinator.report(view.rects(for: highlights))
        }
        let attributes: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: color, .paragraphStyle: Self.centred]
        view.typingAttributes = attributes
        guard view.markedTextRange == nil else { return }
        let style = Style(font: font, color: color, highlights: highlights, highlightColor: highlightColor)
        if context.coordinator.replacement != replacement {
            context.coordinator.replacement = replacement
            view.text = text
            view.selectedRange = NSRange(location: (text as NSString).length, length: 0)
        } else if context.coordinator.style == style {
            return
        }
        context.coordinator.style = style
        // Restyled in place, so the cursor stays where the typing left it.
        let storage = view.textStorage
        storage.beginEditing()
        storage.setAttributes(attributes, range: NSRange(location: 0, length: storage.length))
        for range in highlights where NSMaxRange(range) <= storage.length {
            storage.addAttribute(.foregroundColor, value: highlightColor, range: range)
        }
        storage.endEditing()
        view.invalidateIntrinsicContentSize()
        view.setNeedsLayout()
    }

    func sizeThatFits(_ proposal: ProposedViewSize, uiView: TitleTextView, context: Context) -> CGSize? {
        guard let width = proposal.width, width.isFinite else { return nil }
        let fitting = uiView.sizeThatFits(CGSize(width: width, height: .greatestFiniteMagnitude))
        return CGSize(width: width, height: ceil(fitting.height))
    }

    func makeCoordinator() -> Coordinator { Coordinator(parent: self) }

    private static let centred: NSParagraphStyle = {
        let style = NSMutableParagraphStyle()
        style.alignment = .center
        return style
    }()

    /// What the text was last styled with.
    struct Style: Equatable {
        let font: UIFont
        let color: UIColor
        let highlights: [NSRange]
        let highlightColor: UIColor
    }

    final class Coordinator: NSObject, UITextViewDelegate {
        var parent: HighlightingTitleField
        var style: Style?
        var replacement = 0
        private var reported: [CGRect] = []

        init(parent: HighlightingTitleField) { self.parent = parent }

        func textView(_ textView: UITextView, shouldChangeTextIn range: NSRange, replacementText replacement: String) -> Bool {
            guard replacement.contains("\n") else { return true }
            textView.resignFirstResponder()
            parent.onReturn()
            return false
        }

        func textViewDidChange(_ textView: UITextView) {
            parent.text = textView.text
        }

        /// Told only when the rects change, and after the layout pass, so SwiftUI state is not changed while it draws.
        func report(_ rects: [CGRect]) {
            guard rects != reported else { return }
            reported = rects
            let onFrames = parent.onHighlightFrames
            DispatchQueue.main.async { onFrames(rects) }
        }
    }
}

/// The text view of `HighlightingTitleField`: takes the keyboard when it first appears, tells its layout.
final class TitleTextView: UITextView {
    var onLayout: () -> Void = {}
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

    override func layoutSubviews() {
        super.layoutSubviews()
        onLayout()
    }

    /// The rects the characters of `ranges` take, a rect per line.
    func rects(for ranges: [NSRange]) -> [CGRect] {
        ranges.flatMap { range -> [CGRect] in
            guard NSMaxRange(range) <= (text as NSString).length,
                  let start = position(from: beginningOfDocument, offset: range.location),
                  let end = position(from: start, offset: range.length),
                  let textRange = textRange(from: start, to: end) else { return [] }
            return selectionRects(for: textRange).map(\.rect).filter { $0.width > 0 && $0.height > 0 }
        }
    }
}
