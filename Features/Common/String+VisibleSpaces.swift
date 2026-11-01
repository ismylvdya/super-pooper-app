import SwiftUI
import UIKit

extension String {
    private static let noBreakSpace = "\u{00A0}"

    /// The text as it is stored: no-break spaces (pasted, or typed on some keyboards) as ordinary ones.
    var withOrdinarySpaces: String {
        replacingOccurrences(of: Self.noBreakSpace, with: " ")
    }
}
