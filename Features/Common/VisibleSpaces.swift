import SwiftUI

extension String {
    private static let noBreakSpace = "\u{00A0}"

    /// A right-aligned text field hides ordinary spaces at the end of the line, so a typed trailing space
    /// seems to vanish. Showing them as no-break spaces keeps them visible while typing.
    var withVisibleTrailingSpaces: String {
        let trimmed = String(reversed().drop { $0 == " " }.reversed())
        let count = self.count - trimmed.count
        return trimmed + String(repeating: Self.noBreakSpace, count: count)
    }

    /// The text as it is stored: no-break spaces typed or shown by `withVisibleTrailingSpaces` become ordinary spaces.
    var withOrdinarySpaces: String {
        replacingOccurrences(of: Self.noBreakSpace, with: " ")
    }
}

/// A right-aligned settings field whose typed trailing space stays visible: the field's own text turns it into a
/// no-break space as it is typed (a computed binding is not enough, the field keeps what was just typed), and the
/// stored text gets an ordinary one.
struct TrailingSpaceTextField: View {
    let placeholder: LocalizedStringKey
    @Binding var text: String
    @State private var shown = ""

    var body: some View {
        TextField(placeholder, text: $shown)
            .multilineTextAlignment(.trailing)
            .onAppear { shown = text.withVisibleTrailingSpaces }
            .onChange(of: shown) { _, value in
                let visible = value.withVisibleTrailingSpaces
                if visible != value { shown = visible }
                if text != value.withOrdinarySpaces { text = value.withOrdinarySpaces }
            }
            .onChange(of: text) { _, value in
                if value != shown.withOrdinarySpaces { shown = value.withVisibleTrailingSpaces }
            }
    }
}
