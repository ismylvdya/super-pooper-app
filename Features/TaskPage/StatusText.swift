import SwiftUI

enum StatusText {
    static func title(_ status: TaskStatus) -> String {
        switch status {
        case .thisWeek: L10n.string("status.thisWeek")
        case .inProgress: L10n.string("status.inProgress")
        case .halfYear: L10n.string("status.halfYear")
        case .someday: L10n.string("status.someday")
        case .waiting: L10n.string("status.waiting")
        case .done: L10n.string("status.done")
        case .archived: L10n.string("status.archived")
        case .habit: L10n.string("status.habit")
        case .other(let raw): raw
        }
    }
}
