import SwiftUI
import UIKit

extension String {
    private static let noBreakSpace = "\u{00A0}"

    /// The text as it is stored: no-break spaces (pasted, or typed on some keyboards) as ordinary ones.
    var withOrdinarySpaces: String {
        replacingOccurrences(of: Self.noBreakSpace, with: " ")
    }
}

/// A settings field on the right of its row whose typed trailing space stays visible. Right-aligned text drops the
/// spaces at the end of its line (whatever follows them invisibly), so the text is left-aligned in a field exactly
/// as wide as the text with its spaces, and the field stands at the row's right edge: it reads as right-aligned and
/// the space keeps its room. A UIKit field, because a SwiftUI one cannot be sized by its text this way.
struct TrailingSpaceTextField: UIViewRepresentable {
    enum Capitalization { case never, characters }

    /// String Catalog key of the placeholder.
    let placeholder: String
    @Binding var text: String
    var font: UIFont = .preferredFont(forTextStyle: .body)
    var capitalization: Capitalization = .never
    var onSubmit: () -> Void = {}

    func makeUIView(context: Context) -> UITextField {
        let field = UITextField()
        field.delegate = context.coordinator
        field.textAlignment = .left
        field.adjustsFontForContentSizeCategory = true
        field.autocorrectionType = .no
        field.returnKeyType = .done
        field.addTarget(context.coordinator, action: #selector(Coordinator.changed(_:)), for: .editingChanged)
        return field
    }

    /// Only what changed is set: assigning the font or the text again while typing would move the caret.
    func updateUIView(_ field: UITextField, context: Context) {
        context.coordinator.parent = self
        let placeholder = L10n.string(self.placeholder)
        if field.placeholder != placeholder { field.placeholder = placeholder }
        if field.font != font { field.font = font }
        let capitalization: UITextAutocapitalizationType = self.capitalization == .characters ? .allCharacters : .none
        if field.autocapitalizationType != capitalization { field.autocapitalizationType = capitalization }
        if (field.text ?? "").withOrdinarySpaces != text, !field.isEditing { field.text = text }
    }

    /// As wide as its text with the trailing spaces (or the placeholder), while there is room.
    func sizeThatFits(_ proposal: ProposedViewSize, uiView: UITextField, context: Context) -> CGSize? {
        let measured = text.isEmpty ? L10n.string(placeholder) : text
        let width = ceil((measured as NSString).size(withAttributes: [.font: font]).width) + Self.caretRoom
        return CGSize(width: proposal.width.map { min(width, $0) } ?? width, height: uiView.intrinsicContentSize.height)
    }

    /// Room for the caret after the last character.
    private static let caretRoom: CGFloat = 2

    func makeCoordinator() -> Coordinator { Coordinator(parent: self) }

    final class Coordinator: NSObject, UITextFieldDelegate {
        var parent: TrailingSpaceTextField

        init(parent: TrailingSpaceTextField) { self.parent = parent }

        @objc func changed(_ field: UITextField) {
            parent.text = (field.text ?? "").withOrdinarySpaces
        }

        func textFieldShouldReturn(_ field: UITextField) -> Bool {
            field.resignFirstResponder()
            parent.onSubmit()
            return true
        }
    }
}
