import SwiftUI

/// Notes the app moved to the vault's trash: open one to read it, restore it into the tasks folder (its button or a
/// swipe to the left), or delete it for good after a confirmation.
struct TrashScreen: View {
    @Environment(AppModel.self) private var model
    @Environment(\.tokens) private var tokens
    @State private var toDelete: TrashedNote?
    @State private var query = ""
    @State private var isSearching = false
    @State private var titleHeight: CGFloat = 0
    @State private var frames = ListGroupFrames()

    var body: some View {
        let notes = model.trashedNotes.filter { SearchMatcher.matches($0.name, query) }
        List {
            LargePageTitle(height: $titleHeight) { Text("trash.title") }
                .listGroupSpacer()
            if model.trashedNotes.isEmpty {
                Text("trash.empty").secondaryText(.hint)
                    .listGroupSpacer()
            } else {
                ListGroupGap()
                ForEach(Array(notes.enumerated()), id: \.element.id) { index, note in
                    TrashRow(note: note) { toDelete = note }
                        .listGroupRow(group: "trash", id: note.id, index: index, count: notes.count, frames: frames)
                        .actionSwipes(.trash, item: nil) { _ in Task { await model.restore(note) } }
                }
                ListGroupFooter(text: Text("trash.hint"))
            }
        }
        .listGroupStyle()
        .listGroupBacking(frames)
        .titleScrollsIntoBar(L10n.string("trash.title"), titleHeight: titleHeight)
        .appList()
        // The title starts where the other pages' titles start, not under the list's own top margin.
        .contentMargins(.top, 0, for: .scrollContent)
        .pageSearch(query: $query, isSearching: $isSearching, prompt: "search.prompt.tasks")
        .toolbar { ToolbarItem(placement: .topBarTrailing) { SearchBarButton(isSearching: $isSearching, accessibilityID: "trash.search") } }
        .task { await model.refreshTrash() }
        .refreshable { await model.refreshTrash() }
        .alert("trash.delete.title", isPresented: Binding(presenting: $toDelete),
               presenting: toDelete) { note in
            Button("trash.delete", role: .destructive) { Task { await model.deletePermanently(note) } }
            Button("common.cancel", role: .cancel) {}
        } message: { note in
            Text(L10n.format("trash.delete.message", note.name))
        }
    }
}

/// One trashed note: tap shows its text; the buttons restore it or delete it for good.
private struct TrashRow: View {
    @Environment(AppModel.self) private var model
    @Environment(\.tokens) private var tokens
    @Environment(\.icons) private var icons
    let note: TrashedNote
    let onDelete: () -> Void
    @State private var text: String?

    var body: some View {
        HStack(spacing: tokens.space(.iconTextGap)) {
            Button { Task { text = await model.trashedText(note) } } label: {
                VStack(alignment: .leading, spacing: tokens.space(.titleDetailGap)) {
                    Text(note.name).foregroundStyle(tokens.color(.primaryText)).multilineTextAlignment(.leading)
                    if let date = note.trashedAt {
                        Text(DateText.format(date, Date.FormatStyle(date: .abbreviated, time: .shortened), calendar: model.calendar))
                            .secondaryText()
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)
            Button { Task { await model.restore(note) } } label: { Image(systemName: icons[.restore]) }
                .buttonStyle(.borderless)
                .accessibilityLabel(Text("trash.restore"))
            Button(action: onDelete) { Image(systemName: icons[.trash]).foregroundStyle(tokens.color(.destructive)) }
                .buttonStyle(.borderless)
                .accessibilityLabel(Text("trash.delete"))
        }
        .sheet(item: Binding(get: { text.map(TrashText.init) }, set: { if $0 == nil { text = nil } })) { item in
            NavigationStack {
                ScrollView {
                    Text(item.text).font(tokens.font(.noteEditor)).frame(maxWidth: .infinity, alignment: .leading).padding()
                        .textSelection(.enabled)
                }
                .navigationTitle(Text(verbatim: note.name))
                .navigationBarTitleDisplayMode(.inline)
            }
        }
    }
}

private struct TrashText: Identifiable {
    let text: String
    var id: String { text }
}
