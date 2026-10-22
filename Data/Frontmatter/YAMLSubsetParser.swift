import Foundation

/// Parses the value of one top-level frontmatter key: the text after `key:` plus the lines nested under it.
struct YAMLSubsetParser {
    private enum Chomping {
        case clip, strip, keep
    }

    private let key: String
    private var lines: [YAMLSourceLine]
    private var position = 0

    static func parse(key: String, inlineValue: Substring, lineNumber: Int, followingLines: [String]) throws -> YAMLValue {
        let numbered = followingLines.enumerated().map { offset, text in
            YAMLSourceLine(number: lineNumber + 1 + offset, text: Substring(text))
        }
        var parser = YAMLSubsetParser(key: key, lines: numbered)
        let value = try parser.parseMappingValue(inlineValue, lineNumber: lineNumber, mappingIndent: 0)
        if let leftover = try parser.nextContentLine() {
            throw parser.failure("bad indentation", line: leftover.number)
        }
        return value
    }

    private init(key: String, lines: [YAMLSourceLine]) {
        self.key = key
        self.lines = lines
    }

    // MARK: - Block collections

    private mutating func parseMappingValue(_ inline: Substring, lineNumber: Int, mappingIndent: Int) throws -> YAMLValue {
        let text = YAMLLineSyntax.trimmed(inline)
        if text.isEmpty || text.unicodeScalars.first == "#" {
            return try parseNestedNode(parentIndent: mappingIndent, allowsSequenceAtParentIndent: true)
        }
        return try parseInlineNode(text, lineNumber: lineNumber, parentIndent: mappingIndent)
    }

    /// A node on the lines below its key or dash; a block sequence may sit at the key's own indentation.
    private mutating func parseNestedNode(parentIndent: Int, allowsSequenceAtParentIndent: Bool) throws -> YAMLValue {
        guard let line = try nextContentLine() else { return .null }
        if line.indent > parentIndent {
            return try parseBlockNode(line, parentIndent: parentIndent)
        }
        if allowsSequenceAtParentIndent && line.indent == parentIndent && line.isSequenceEntry {
            return try parseSequence(indent: parentIndent)
        }
        return .null
    }

    /// A node starting at `line`, which is the current line.
    private mutating func parseBlockNode(_ line: YAMLSourceLine, parentIndent: Int) throws -> YAMLValue {
        if line.isSequenceEntry {
            return try parseSequence(indent: line.indent)
        }
        if YAMLLineSyntax.mappingEntry(in: line.content) != nil {
            return try parseMapping(indent: line.indent)
        }
        position += 1
        return try parseInlineNode(line.content, lineNumber: line.number, parentIndent: parentIndent)
    }

    private mutating func parseSequence(indent: Int) throws -> YAMLValue {
        var items: [YAMLValue] = []
        while let line = try nextContentLine(), line.indent == indent, line.isSequenceEntry {
            let afterDash = line.content.unicodeScalars.dropFirst()
            let gap = afterDash.prefix(while: YAMLLineSyntax.isWhitespace).count
            let rest = Substring(afterDash.dropFirst(gap))
            if rest.isEmpty || rest.unicodeScalars.first == "#" {
                position += 1
                items.append(try parseNestedNode(parentIndent: indent, allowsSequenceAtParentIndent: false))
            } else {
                // The item's content is read as a line of its own, starting at the column after "- ".
                let itemLine = YAMLSourceLine(number: line.number, indent: indent + 1 + gap, content: rest)
                lines[position] = itemLine
                items.append(try parseBlockNode(itemLine, parentIndent: indent))
            }
        }
        return .list(items)
    }

    private mutating func parseMapping(indent: Int) throws -> YAMLValue {
        var entries: [YAMLMapEntry] = []
        while let line = try nextContentLine(), line.indent == indent {
            guard let entry = YAMLLineSyntax.mappingEntry(in: line.content) else {
                throw failure("expected 'key: value'", line: line.number)
            }
            position += 1
            let value = try parseMappingValue(entry.value, lineNumber: line.number, mappingIndent: indent)
            entries.append(YAMLMapEntry(key: entry.key, value: value))
        }
        return .map(entries)
    }

    // MARK: - Scalars and flow collections

    /// A node whose text starts on an already consumed line; its continuation lines are indented deeper than `parentIndent`.
    private mutating func parseInlineNode(_ text: Substring, lineNumber: Int, parentIndent: Int) throws -> YAMLValue {
        switch text.unicodeScalars.first {
        case "|", ">":
            return try parseBlockScalar(header: text, lineNumber: lineNumber, parentIndent: parentIndent)
        case "\"", "'", "[", "{":
            return try parseFlowNode(text, lineNumber: lineNumber, parentIndent: parentIndent)
        default:
            return try parsePlainScalar(text, lineNumber: lineNumber, parentIndent: parentIndent)
        }
    }

    private mutating func parseFlowNode(_ text: Substring, lineNumber: Int, parentIndent: Int) throws -> YAMLValue {
        var joined = String(text)
        while position < lines.count, isContinuation(lines[position], parentIndent: parentIndent) {
            joined += "\n" + lines[position].text
            position += 1
        }
        var parser = YAMLFlowParser(Substring(joined), key: key, firstLineNumber: lineNumber)
        return try parser.parseCompleteValue()
    }

    private func isContinuation(_ line: YAMLSourceLine, parentIndent: Int) -> Bool {
        line.isBlank || line.isComment || line.indent > parentIndent
    }

    private mutating func parsePlainScalar(_ text: Substring, lineNumber: Int, parentIndent: Int) throws -> YAMLValue {
        let first = YAMLLineSyntax.strippingComment(text)
        var parts = [String(first.text)]
        var endsWithComment = first.hadComment
        var scan = position
        var emptyLines = 0
        while !endsWithComment && scan < lines.count {
            let line = lines[scan]
            scan += 1
            if line.isBlank {
                emptyLines += 1
                continue
            }
            guard line.indent > parentIndent, !line.isComment else { break }
            let part = YAMLLineSyntax.strippingComment(line.content)
            parts += Array(repeating: "", count: emptyLines) + [String(part.text)]
            emptyLines = 0
            endsWithComment = part.hadComment
            position = scan
        }
        let folded = YAMLLineSyntax.fold(parts)
        if folded.contains(": ") || folded.contains(":\t") || folded.hasSuffix(":") {
            throw failure("':' followed by a space needs quotes", line: lineNumber)
        }
        return YAMLLineSyntax.plainScalarValue(folded)
    }

    /// Literal `|` and folded `>` scalars with chomping and indentation indicators.
    private mutating func parseBlockScalar(header: Substring, lineNumber: Int, parentIndent: Int) throws -> YAMLValue {
        let headerScalars = YAMLLineSyntax.strippingComment(header).text.unicodeScalars
        var chomping = Chomping.clip
        var explicitIndent: Int?
        for scalar in headerScalars.dropFirst() {
            switch scalar {
            case "-" where chomping == .clip: chomping = .strip
            case "+" where chomping == .clip: chomping = .keep
            case "1"..."9" where explicitIndent == nil: explicitIndent = Int(String(scalar))
            default: throw failure("invalid block scalar header", line: lineNumber)
            }
        }
        let collected = collectBlockScalarLines(contentIndent: explicitIndent.map { parentIndent + $0 }, parentIndent: parentIndent)
        let contentCount = (collected.lastIndex { !$0.isEmpty } ?? -1) + 1
        let content = Array(collected.prefix(contentCount))
        var text = headerScalars.first == ">" ? YAMLLineSyntax.fold(content) : content.joined(separator: "\n")
        let finalBreak = content.isEmpty ? "" : "\n"
        switch chomping {
        case .strip: break
        case .clip: text += finalBreak
        case .keep: text += finalBreak + String(repeating: "\n", count: collected.count - contentCount)
        }
        return .scalar(text, quoted: true)
    }

    /// Lines of a block scalar with the content indentation removed; blank lines become "".
    private mutating func collectBlockScalarLines(contentIndent explicitIndent: Int?, parentIndent: Int) -> [String] {
        var contentIndent = explicitIndent
        var collected: [String] = []
        while position < lines.count {
            let line = lines[position]
            if line.isBlank {
                collected.append("")
            } else {
                let indent = contentIndent ?? line.indent
                guard line.indent > parentIndent, line.indent >= indent else { break }
                contentIndent = indent
                collected.append(String(repeating: " ", count: line.indent - indent) + line.content)
            }
            position += 1
        }
        return collected
    }

    // MARK: - Lines

    /// Skips blank and comment lines and returns the current line without consuming it.
    private mutating func nextContentLine() throws -> YAMLSourceLine? {
        while position < lines.count {
            let line = lines[position]
            if line.isBlank || line.isComment {
                position += 1
                continue
            }
            if line.content.unicodeScalars.first == "\t" {
                throw failure("tab indentation", line: line.number)
            }
            return line
        }
        return nil
    }

    private func failure(_ reason: String, line: Int) -> FrontmatterError {
        .malformedValue(key: key, line: line, reason: reason)
    }
}
