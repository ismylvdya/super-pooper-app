import SwiftUI

/// The bar's "…" of every page that has a search: Search first, then the page's own things, then Undo and Redo of the
/// latest action. The search also opens on a hold of the bar's title (`searchOnTitleHold`), which the page sets with the
/// same action.
struct PageMoreMenu<Extra: View>: View {
    @Environment(AppModel.self) private var model
    @Environment(\.icons) private var icons
    let search: () -> Void
    var accessibilityID = "page.more"
    @ViewBuilder let extra: () -> Extra

    var body: some View {
        MoreMenu(accessibilityID: accessibilityID) {
            Button(action: search) { Label("search.title", systemImage: icons[.search]) }
                .accessibilityIdentifier("\(accessibilityID).search")
            extra()
            Section {
                Button { Task { await model.undoLast() } } label: { Label("common.undo", systemImage: icons[.undo]) }
                    .disabled(!model.canUndo)
                    .accessibilityIdentifier("\(accessibilityID).undo")
                Button { Task { await model.redoLast() } } label: { Label("common.redo", systemImage: icons[.redo]) }
                    .disabled(!model.canRedo)
                    .accessibilityIdentifier("\(accessibilityID).redo")
            }
        }
    }
}

extension PageMoreMenu where Extra == EmptyView {
    init(search: @escaping () -> Void, accessibilityID: String = "page.more") {
        self.init(search: search, accessibilityID: accessibilityID) { EmptyView() }
    }
}
