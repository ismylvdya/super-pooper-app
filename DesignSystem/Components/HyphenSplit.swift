import UIKit

/// Splits a title into a first line of as many letters as fit `width` (ending with a hyphen when a word
/// is cut) and the rest.
enum HyphenSplit {
    static func split(_ text: String, width: CGFloat, font: UIFont) -> (first: String, rest: String) {
        let attributes: [NSAttributedString.Key: Any] = [.font: font]
        func fits(_ value: String) -> Bool { (value as NSString).size(withAttributes: attributes).width <= width }
        guard !fits(text) else { return (text, "") }
        var count = 0
        let characters = Array(text)
        while count < characters.count, fits(String(characters[0...count]) + "-") { count += 1 }
        guard count > 0 else { return ("", text) }
        let head = String(characters[0..<count])
        let tail = String(characters[count...])
        let cutsWord = head.last.map { !$0.isWhitespace } == true && tail.first.map { !$0.isWhitespace } == true
        return (cutsWord ? head + "-" : head.trimmingCharacters(in: .whitespaces), tail.trimmingCharacters(in: .whitespaces))
    }
}
