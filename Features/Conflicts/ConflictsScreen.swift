import SwiftUI

/// Notes that iCloud has in more than one version. The app never picks one by itself: each note
/// opens a page where the user compares the versions and keeps one.
struct ConflictsScreen: View {
    @Environment(AppModel.self) private var model
    @Environment(\.tokens) private var tokens
    @Environment(\.icons) private var icons

    var body: some View {
        PageScaffold(title: L10n.string("conflicts.title")) {
            if model.conflictedNotes.isEmpty {
                Text("conflicts.empty").font(tokens.font(.hint)).foregroundStyle(tokens.color(.secondaryText))
            } else {
                PlateSection(header: nil, hint: "conflicts.hint") {
                    ForEach(model.conflictedNotes, id: \.self) { name in
                        NavigationLink(value: Route.conflict(name)) {
                            PlateRow(icon: .problem, title: LocalizedStringKey(name), tint: tokens.color(.warning)) {
                                Image(systemName: icons[.chevron]).foregroundStyle(tokens.color(.tertiaryText))
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }
}

/// The versions of one note side by side (stacked): where and when each was saved, its full text, and
/// "Keep this version". The others are dropped after a backup.
struct ConflictVersionsScreen: View {
    @Environment(AppModel.self) private var model
    @Environment(Router.self) private var router
    @Environment(\.tokens) private var tokens
    let noteName: String
    @State private var versions: [NoteVersion] = []
    @State private var toKeep: NoteVersion?

    var body: some View {
        PageScaffold(title: noteName) {
            ForEach(versions) { version in
                PlateSection(header: LocalizedStringKey(title(version)), hint: LocalizedStringKey(detail(version))) {
                    Text(version.text)
                        .font(tokens.font(.noteEditor))
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .textSelection(.enabled)
                    Button("conflicts.keep") { toKeep = version }
                        .buttonStyle(.borderedProminent)
                        .frame(maxWidth: .infinity)
                        .accessibilityIdentifier("conflict.keep.\(version.id)")
                }
            }
        }
        .task(id: noteName) { versions = await model.versions(of: noteName) }
        .alert("conflicts.keep.title", isPresented: Binding(get: { toKeep != nil }, set: { if !$0 { toKeep = nil } }),
               presenting: toKeep) { version in
            Button("conflicts.keep") {
                Task {
                    await model.keep(version, of: noteName)
                    router.popToRoot()
                }
            }
            Button("common.cancel", role: .cancel) {}
        } message: { _ in
            Text("conflicts.keep.message")
        }
    }

    private func title(_ version: NoteVersion) -> String {
        version.isCurrent ? L10n.string("conflicts.current") : L10n.format("conflicts.other", version.device ?? L10n.string("conflicts.unknownDevice"))
    }

    private func detail(_ version: NoteVersion) -> String {
        version.modified.map { L10n.format("conflicts.saved", $0.formatted(date: .abbreviated, time: .standard)) } ?? ""
    }
}
