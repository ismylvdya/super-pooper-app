import Foundation

/// Why a name cannot be a note's name.
enum NoteNameProblem: Equatable, Sendable {
    case empty
    case spacesAround
    case leadingDot
    case forbidden(Character)
    case tooLong(limit: Int)
}
