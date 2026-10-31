import Foundation

/// What is wrong with a typed note name, in words under the name field.
enum NoteNameProblemText {
    static func describe(_ problem: NoteNameProblem, name: String) -> String {
        switch problem {
        case .empty, .spacesAround: L10n.format("error.rename.invalid", name)
        case .leadingDot: L10n.string("noteName.problem.leadingDot")
        case .forbidden(let character): L10n.format("noteName.problem.forbidden", String(character))
        case .tooLong(let limit): L10n.format("noteName.problem.tooLong", limit)
        }
    }
}
