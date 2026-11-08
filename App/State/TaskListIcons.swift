import UIKit

/// The icon of each list: what the user typed in the settings when it is a real SF Symbol, otherwise `icons.json`. Done has
/// the app's done mark always.
struct TaskListIcons {
    let icons: IconSet
    let typed: [String: String]

    /// The lists whose icons can be changed, as the settings name them.
    static let editable: [(name: TaskStatus.Name, title: String)] = [
        (.thisWeek, "status.thisWeek"), (.halfYear, "status.halfYear"), (.someday, "status.someday"),
    ]

    func symbol(of status: TaskStatus) -> String {
        switch status {
        case .thisWeek: valid(.thisWeek) ?? icons[.listsGun]
        case .halfYear: valid(.halfYear) ?? icons[.listHalfYear]
        case .someday: valid(.someday) ?? icons[.listSomeday]
        case .custom: icons[.listCustom]
        default: icons[.markDone]
        }
    }

    /// What a hand-drawn icon is sized against.
    func symbols(besides status: TaskStatus) -> [String] {
        TaskStatus.known.filter { $0 != status }.map(symbol(of:)).filter { UIImage(systemName: $0) != nil }
    }

    private func valid(_ name: TaskStatus.Name) -> String? {
        typed[name.rawValue].flatMap { UIImage(systemName: $0) == nil ? nil : $0 }
    }
}
