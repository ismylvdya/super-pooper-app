import Foundation

/// A field of a task or habit in words (problems, the "changed elsewhere" banner).
enum TaskFieldText {
    static func title(_ field: TaskField) -> String {
        L10n.string("field." + field.rawValue)
    }
}
