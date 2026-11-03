import Foundation

/// One way of writing a date or a time (`DateGrammar`), compiled once, and what a match of it means.
struct DatePattern: @unchecked Sendable {
    /// What a match stands for: a day, a time of day, or a moment that is both ("in 5 min").
    enum Meaning: Equatable {
        case day(LocalDate)
        case time(LocalTime)
        case moment(TaskDue)
    }

    /// A match of a pattern in the text: its NSRange and the captured groups by name.
    struct Match {
        let range: NSRange
        let groups: [String: String]
    }

    let regex: NSRegularExpression
    let groupNames: [String]
    let meaning: (Match, DayContext) -> Meaning?

    init(_ pattern: String, groups: [String], meaning: @escaping (Match, DayContext) -> Meaning?) {
        // A word of the grammar stands alone: no letter or digit right before or after, and a number does not go on
        // past a separator ("6.11b", "6.11.20" are not "6.11").
        let whole = #"(?<![\p{L}\p{N}])(?:"# + pattern + #")(?![\p{L}\p{N}]|[.:]\p{N})"#
        do {
            regex = try NSRegularExpression(pattern: whole, options: [.caseInsensitive])
        } catch {
            preconditionFailure("Date pattern does not compile: \(whole)")
        }
        groupNames = groups
        self.meaning = meaning
    }

    func matches(in text: String) -> [Match] {
        let all = NSRange(text.startIndex..., in: text)
        return regex.matches(in: text, range: all).map { result in
            var groups: [String: String] = [:]
            for name in groupNames {
                let range = result.range(withName: name)
                if range.location != NSNotFound, let swiftRange = Range(range, in: text) {
                    groups[name] = String(text[swiftRange]).lowercased()
                }
            }
            return Match(range: result.range, groups: groups)
        }
    }

    /// `words` as alternatives of a pattern: escaped, the longest first, spaces matching any run of spaces.
    static func alternatives(_ words: [String]) -> String {
        let sorted = words.map { $0.lowercased() }.sorted { $0.count > $1.count }
        return "(?:" + sorted.map { NSRegularExpression.escapedPattern(for: $0).replacingOccurrences(of: " ", with: #"\s+"#) }
            .joined(separator: "|") + ")"
    }
}
