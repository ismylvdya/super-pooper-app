import UIKit

/// Which symbol each place of the tab bar shows: what the user typed in the settings when it is a real SF Symbol, otherwise
/// `icons.json`. A selected tab without one of its own looks as it does when not selected.
struct TabBarSymbols {
    let typed: [String: String]
    let icons: IconSet

    static func key(_ tab: AppTab, isSelected: Bool) -> String { tab.rawValue + (isSelected ? ".selected" : "") }
    static let newItemKey = "newItem"

    func symbol(of tab: AppTab, isSelected: Bool) -> String {
        let own = isSelected ? valid(Self.key(tab, isSelected: true)) : nil
        return own ?? valid(Self.key(tab, isSelected: false)) ?? icons[tab.icon]
    }

    var newItem: String { valid(Self.newItemKey) ?? icons[.newItem] }

    private func valid(_ key: String) -> String? {
        typed[key].flatMap { Self.exists($0) ? $0 : nil }
    }

    static func exists(_ symbol: String) -> Bool { UIImage(systemName: symbol) != nil }
}
