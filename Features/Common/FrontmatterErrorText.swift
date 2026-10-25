import Foundation

/// What is wrong with a note's YAML, in words for the problems list.
enum FrontmatterErrorText {
    static func describe(_ error: FrontmatterError) -> String {
        switch error {
        case .noFrontmatter: L10n.string("yaml.noFrontmatter")
        case .unterminated: L10n.string("yaml.unterminated")
        case .malformedLine(let line, let text): L10n.format("yaml.malformedLine", line, text)
        case .malformedValue(let key, let line, let reason): L10n.format("yaml.malformedValue", key, line, reason)
        }
    }
}
