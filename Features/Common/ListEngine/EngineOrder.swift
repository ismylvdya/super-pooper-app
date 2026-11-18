import ListEngineChumbulev
import SwiftUI

/// A thing of the app put in an order of the user's (a pool rule, a chip kind, a habit of a routine), as a row of the
/// list engine: only its name.
struct OrderedRow: Identifiable, Hashable {
    let id: String
}

/// What an order list does: rows are carried, nothing else — no menu, no swipes (the lift stays).
extension ListFeatures {
    static let orderOnly: ListFeatures = [.carry, .haptics, .autoscroll]
}

/// Under an order list: what it is about, and the button that brings the default order back.
struct OrderFooter: View {
    @Environment(\.tokens) private var tokens
    let hint: LocalizedStringKey
    let reset: LocalizedStringKey
    let canReset: Bool
    let action: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: tokens.space(.plateInner)) {
            PlateHint(text: Text(hint))
            Button(reset, action: action)
                .disabled(!canReset)
                .padding(.horizontal, tokens.space(.plateInner))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, ListTheme.app.rows.sideInset)
        .padding(.bottom, tokens.space(.plateInner))
    }
}

extension Array {
    /// One section of rows without a title, for an order list (`ReorderableList`).
    static func single<Item>(_ items: [Item]) -> [ListSection<Item>] where Element == ListSection<Item> {
        [ListSection(id: "order", title: "", items: items)]
    }
}
