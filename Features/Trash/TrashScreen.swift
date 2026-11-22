import ListEngineChumbulev
import SwiftUI

/// Notes the app moved to the vault's trash, in a list of the list engine: a tap shows a note's text; swiped to the
/// right it goes back into the tasks folder; to the left it is deleted for good, after a confirmation. Nothing is
/// carried, there is no menu.
struct TrashScreen: View {
    @Environment(AppModel.self) private var model
    @Environment(\.tokens) private var tokens
    @Environment(\.icons) private var icons
    @Environment(\.actions) private var registry
    @Environment(Router.self) private var router
    /// Shown as the search's results (`SearchPage`): the notes matching it, without the title and bar items.
    var searchQuery: String?
    @State private var toDelete: TrashedNote?
    @State private var text: TrashText?

    var body: some View {
        let notes = model.trashedNotes.filter { SearchMatcher.matches($0.name, searchQuery ?? "") }
        ReorderableList(sections: .constant([ListSection(id: "trash", title: "", items: notes)]), look: "lists",
                        swipes: swipes, features: [.swipes, .haptics, .scrollIndicator, .wrapTitles],
                        onTap: { note in Task { text = TrashText(text: await model.trashedText(note)) } },
                        footer: AnyView(PlateHint(text: Text(model.trashedNotes.isEmpty ? "trash.empty" : "trash.hint"))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, ListTheme.app.rows.sideInset))) { note in
            TrashRow(note: note)
        }
        .ignoresSafeArea()
        .applying(if: searchQuery == nil) { page in
            page
                .navigationTitle(Text("trash.title"))
                .navigationBarTitleDisplayMode(.large)
                .searchOnTitleHold { router.open(.search(.trash)) }
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        PageMoreMenu(search: { router.open(.search(.trash)) }, accessibilityID: "trash.more")
                    }
                }
        }
        .task { await model.refreshTrash() }
        .alert("trash.delete.title", isPresented: Binding(presenting: $toDelete),
               presenting: toDelete) { note in
            Button("trash.delete", role: .destructive) { Task { await model.deletePermanently(note) } }
            Button("common.cancel", role: .cancel) {}
        } message: { note in
            Text(L10n.format("trash.delete.message", note.name))
        }
        .sheet(item: $text) { item in
            NavigationStack {
                ScrollView {
                    Text(item.text).font(tokens.font(.noteEditor)).frame(maxWidth: .infinity, alignment: .leading).padding()
                        .textSelection(.enabled)
                }
            }
        }
    }

    /// To the right, back among the tasks; to the left, deleted for good once confirmed.
    private func swipes(_ note: TrashedNote) -> ListSwipes {
        let restore = registry.definition(.restoreFromTrash)
        return ListSwipes(
            leading: ListSwipe(title: L10n.string(restore.title), icon: .app(restore.icon),
                               color: ThemeColor(tokens.uiColor(restore.swipeTint.flatMap(ColorToken.init(rawValue:)) ?? .accent))) {
                Haptics.play(restore.haptic)
                Task { await model.restore(note) }
            },
            trailing: ListSwipe(title: L10n.string("trash.delete"), icon: .app(icons[.trash]), color: ThemeColor(tokens.uiColor(.destructive))) {
                toDelete = note
            })
    }
}

/// One trashed note: its name, and when it was moved to the trash.
private struct TrashRow: View {
    @Environment(AppModel.self) private var model
    @Environment(\.tokens) private var tokens
    let note: TrashedNote

    var body: some View {
        VStack(alignment: .leading, spacing: tokens.space(.titleDetailGap)) {
            Text(note.name).foregroundStyle(tokens.color(.primaryText)).multilineTextAlignment(.leading)
            if let date = note.trashedAt {
                Text(DateText.format(date, Date.FormatStyle(date: .abbreviated, time: .shortened), calendar: model.calendar))
                    .secondaryText()
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct TrashText: Identifiable {
    let text: String
    var id: String { text }
}
