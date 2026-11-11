import SwiftUI

/// The bar's "…" of every page that has a search: Search first, then the page's own things, then Undo and Redo of the
/// latest action. The search also opens on a hold of the bar's title (`searchOnTitleHold`), which the page sets with the
/// same action.
struct PageMoreMenu<Extra: View>: View {
    @Environment(AppModel.self) private var model
    @Environment(\.icons) private var icons
    @Environment(\.tokens) private var tokens
    let search: () -> Void
    var accessibilityID = "page.more"
    @ViewBuilder let extra: () -> Extra

    var body: some View {
        MoreMenu(accessibilityID: accessibilityID) {
            Button(action: search) { Label("search.title", systemImage: icons[.search]) }
                .accessibilityIdentifier("\(accessibilityID).search")
            extra()
            Section {
                step("common.undo", icon: .undo, isOn: model.canUndo, id: "undo") { await model.undoLast() }
                step("common.redo", icon: .redo, isOn: model.canRedo, id: "redo") { await model.redoLast() }
            }
        }
    }
}

extension PageMoreMenu {
    /// Undo or Redo; when there is nothing to take back or do again, its icon is as dim as its title (a menu keeps a
    /// template icon bright on a disabled row).
    fileprivate func step(_ title: LocalizedStringKey, icon: Icon, isOn: Bool, id: String,
                          run: @escaping () async -> Void) -> some View {
        Button { Task { await run() } } label: {
            Label {
                Text(title)
            } icon: {
                if isOn {
                    Image(systemName: icons[icon])
                } else if let dim = UIImage(systemName: icons[icon])?.withTintColor(tokens.uiColor(.tertiaryText), renderingMode: .alwaysOriginal) {
                    Image(uiImage: dim)
                }
            }
        }
        .disabled(!isOn)
        .accessibilityIdentifier("\(accessibilityID).\(id)")
    }
}

extension PageMoreMenu where Extra == EmptyView {
    init(search: @escaping () -> Void, accessibilityID: String = "page.more") {
        self.init(search: search, accessibilityID: accessibilityID) { EmptyView() }
    }
}
