import SwiftUI

/// Notes the app moved to the vault's trash: open one to read it, restore it into the tasks folder,
/// or delete it for good after a confirmation.
struct TrashScreen: View {
    @Environment(AppModel.self) private var model
    @Environment(\.tokens) private var tokens
    @State private var toDelete: TrashedNote?
    @State private var query = ""
    @State private var isSearching = false

    var body: some View {
        PageScaffold(title: L10n.string("trash.title")) {
            if model.trashedNotes.isEmpty {
                Text("trash.empty").font(tokens.font(.hint)).foregroundStyle(tokens.color(.secondaryText))
            } else {
                PlateSection(header: nil, hint: "trash.hint") {
                    ForEach(model.trashedNotes.filter { SearchMatcher.matches($0.name, query) }) { note in
                        TrashRow(note: note) { toDelete = note }
                    }
                }
            }
        }
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
                        Text(date.formatted(date: .abbreviated, time: .shortened))
                            .font(tokens.font(.caption)).foregroundStyle(tokens.color(.secondaryText))
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
