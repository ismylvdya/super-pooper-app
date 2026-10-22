import Foundation

/// Checks that a value opening with a quote or a flow bracket is closed and followed only by a comment,
/// without interpreting it. Lets a note be validated on load while unknown keys stay unparsed.
struct YAMLBalanceScanner {
    struct Problem: Equatable {
        let reason: String
        /// Zero-based line within the scanned text.
        let lineOffset: Int
    }

    private static let flowClosers: [Unicode.Scalar: Unicode.Scalar] = ["[": "]", "{": "}"]
    private static let flowIndicators: Set<Unicode.Scalar> = [",", "[", "]", "{", "}"]

    private let scalars: [Unicode.Scalar]
    private var index = 0
    private var line = 0
    private var openBrackets: [(closer: Unicode.Scalar, line: Int)] = []
    private var openQuote: (quote: Unicode.Scalar, line: Int)?
    private var expectsScalar = true
    private var isComplete = false

    static func problem(in text: String) -> Problem? {
        var scanner = YAMLBalanceScanner(scalars: Array(text.unicodeScalars))
        return scanner.scan()
    }

    private init(scalars: [Unicode.Scalar]) {
        self.scalars = scalars
    }

    private mutating func scan() -> Problem? {
        while index < scalars.count {
            let scalar = scalars[index]
            let previous: Unicode.Scalar = index > 0 ? scalars[index - 1] : " "
            index += 1
            if scalar == "\n" { line += 1 }
            if let open = openQuote {
                scanQuoted(scalar, quote: open.quote)
            } else if scalar == "#" && Self.isSpace(previous) {
                skipComment()
            } else if !Self.isSpace(scalar) {
                if isComplete { return Problem(reason: "unexpected text after the value", lineOffset: line) }
                if let problem = scanStructure(scalar, previous: previous) { return problem }
            }
        }
        if let open = openQuote {
            let style = open.quote == "\"" ? "double" : "single"
            return Problem(reason: "unterminated \(style)-quoted string", lineOffset: open.line)
        }
        if let outermost = openBrackets.first {
            let name = outermost.closer == "]" ? "flow sequence" : "flow mapping"
            return Problem(reason: "unterminated \(name)", lineOffset: outermost.line)
        }
        return nil
    }

    private mutating func scanQuoted(_ scalar: Unicode.Scalar, quote: Unicode.Scalar) {
        if quote == "\"" && scalar == "\\" {
            if index < scalars.count && scalars[index] == "\n" { line += 1 }
            index += 1
        } else if scalar == quote {
            if quote == "'" && index < scalars.count && scalars[index] == "'" {
                index += 1
            } else {
                openQuote = nil
                expectsScalar = false
                isComplete = openBrackets.isEmpty
            }
        }
    }

    private mutating func scanStructure(_ scalar: Unicode.Scalar, previous: Unicode.Scalar) -> Problem? {
        switch scalar {
        case "\"", "'":
            if expectsScalar { openQuote = (scalar, line) }
        case "[", "{":
            openBrackets.append((Self.flowClosers[scalar] ?? scalar, line))
            expectsScalar = true
        case "]", "}":
            guard openBrackets.last?.closer == scalar else {
                return Problem(reason: "unbalanced '\(scalar)'", lineOffset: line)
            }
            openBrackets.removeLast()
            expectsScalar = false
            isComplete = openBrackets.isEmpty
        case ",":
            expectsScalar = true
        case ":":
            let next: Unicode.Scalar? = index < scalars.count ? scalars[index] : nil
            let isIndicator = next.map { Self.isSpace($0) || Self.flowIndicators.contains($0) } ?? true
            expectsScalar = isIndicator || previous == "\"" || previous == "'"
        default:
            expectsScalar = false
        }
        return nil
    }

    private mutating func skipComment() {
        while index < scalars.count && scalars[index] != "\n" { index += 1 }
    }

    private static func isSpace(_ scalar: Unicode.Scalar) -> Bool {
        scalar == " " || scalar == "\t" || scalar == "\n"
    }
}
