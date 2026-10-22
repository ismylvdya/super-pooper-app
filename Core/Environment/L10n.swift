import Foundation

/// String Catalog lookups for text built outside SwiftUI views (banners, notifications).
enum L10n {
    static func string(_ key: String) -> String {
        Bundle.main.localizedString(forKey: key, value: nil, table: nil)
    }

    static func format(_ key: String, _ arguments: CVarArg...) -> String {
        String(format: string(key), arguments: arguments)
    }

    /// "A, B and C" in the current locale.
    static func list(_ items: [String]) -> String {
        ListFormatter.localizedString(byJoining: items)
    }
}
