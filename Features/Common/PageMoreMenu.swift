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
                AvailabilityMenuButton(title: "common.undo", icon: .undo, isEnabled: model.canUndo) { await model.undoLast() }
                    .accessibilityIdentifier("\(accessibilityID).undo")
                AvailabilityMenuButton(title: "common.redo", icon: .redo, isEnabled: model.canRedo) { await model.redoLast() }
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
