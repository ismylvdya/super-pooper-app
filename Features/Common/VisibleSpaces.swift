import Foundation

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
