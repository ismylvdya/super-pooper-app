import Foundation

/// A note name that is not taken yet: the name itself, then "Name 2", "Name 3"… (or from another first number).
enum UniqueName {
    static func free(_ base: String, firstNumber: Int = 2, isTaken: (String) -> Bool) -> String {
        guard isTaken(base) else { return base }
        var number = firstNumber
        while isTaken("\(base) \(number)") { number += 1 }
        return "\(base) \(number)"
    }
}
