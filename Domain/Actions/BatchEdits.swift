import Foundation

/// What an action of Select mode writes when the selected notes differ.
enum BatchEdits {
    /// High priority turns on for all of them, unless all of them have it already: then it turns off.
    static func highPriority(for tasks: [TaskItem]) -> Bool {
        !tasks.allSatisfy(\.isHighPriority)
    }
}
