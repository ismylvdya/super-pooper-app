import SwiftUI

/// The "…" button: the system menu with the registry's actions for the note (`actions.json`), the same buttons as every
/// long-press menu of the app (`ActionMenuContent`). A confirmation the chosen action asks for comes after the menu, as
/// from a long-press menu.
struct ActionMenuButton: View {
    @Environment(\.tokens) private var tokens
    @Environment(\.icons) private var icons
    let menu: ActionMenu
    /// What the menu is about, so it offers only what fits its state (an archived note: Restore from archive).
    var item: DayItem?
    var accessibilityID = "more"
    let perform: (ActionDefinition) -> Void

    var body: some View {
        Menu {
            ActionMenuContent(menu: menu, item: item, perform: perform)
        } label: {
            Image(systemName: icons[.more])
        }
        .tint(tokens.color(.accentToolbar))
        .accessibilityLabel(Text("taskPage.more"))
        .accessibilityIdentifier(accessibilityID)
    }
}
