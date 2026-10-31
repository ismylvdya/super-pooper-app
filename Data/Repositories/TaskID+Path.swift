import Foundation

/// A TaskNotes item is its note file: the identity is the note's path from the chosen folder.
extension TaskID {
    init(relativePath: String) {
        self.init(relativePath)
    }

    var relativePath: String { value }
}
