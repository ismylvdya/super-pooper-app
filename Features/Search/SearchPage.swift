import SwiftUI
import UIKit

/// The one search of the app, a page of its own opened from a page's "…" or a hold of its title: Back on the left, the
/// field in the middle saying what it looks through (`SearchScope`), on the right an X that empties the field — dim
/// while there is nothing in it. Empty, the page says what to type; typed, what matches, in titled groups — the same rows
/// for every search of notes (`NoteSearchResults`, `SearchSections`): Today's and the Lists page's every task (and
/// Today's events), the habits, the archive, a list. Settings and the trash, which hold no notes, show their own rows.
struct SearchPage: View {
    @Environment(AppModel.self) private var model
    @Environment(\.tokens) private var tokens
    @Environment(\.icons) private var icons
    let scope: SearchScope
    @State private var query = ""
    /// The page's width, kept from the last search, so the field stands at its width from the first frame.
    @State private var width = SearchPage.lastWidth
    @MainActor private static var lastWidth: CGFloat = 0
    /// The field, for the keyboard to come up once the page is in.
    @State private var field = SearchFieldFocus()

    var body: some View {
        content
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { new in
                width = new
                SearchPage.lastWidth = new
            }
            .navigationBarTitleDisplayMode(.inline)
            .background { SearchKeyboard(field: field).frame(width: 0, height: 0) }
            .toolbar {
                ToolbarItem(placement: .principal) {
                    SearchBarField(text: $query, prompt: prompt, focus: field).frame(width: fieldWidth, height: tokens.bar(.uprightBarButton))
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { query = "" } label: { Image(systemName: icons[.close]) }
                        .disabled(query.isEmpty)
                        .tint(tokens.color(.accent))
                        .accessibilityLabel(Text("search.clear"))
                        .accessibilityIdentifier("search.clear")
                }
            }
    }

    @ViewBuilder private var content: some View {
        let text = query.trimmingCharacters(in: .whitespacesAndNewlines)
        if text.isEmpty {
            List { Text(LocalizedStringKey(hint)).foregroundStyle(tokens.color(.secondaryText)).listRowBackground(Color.clear) }
                .appList()
        } else {
            results(text)
        }
    }

    @ViewBuilder private func results(_ text: String) -> some View {
        switch scope {
        case .tasksAndEvents:
            NoteSearchResults(sections: SearchSections.notes(model.tasks, matching: text),
                              events: SearchMatcher.events(model.events, matching: text))
        case .tasks: NoteSearchResults(sections: SearchSections.notes(model.tasks, matching: text))
        case .habits: NoteSearchResults(sections: SearchSections.habits(model.habits, matching: text))
        case .archive: NoteSearchResults(sections: SearchSections.archive(model.archivedTasks + model.archivedHabits, matching: text))
        case .list(let id): NoteSearchResults(sections: SearchSections.list(model.listContents(id, query: text), levelTitle: StatusText.title))
        case .settings: SettingsScreen(searchQuery: text)
        case .trash: TrashScreen(searchQuery: text)
        }
    }

    /// What the empty page says to type.
    private var hint: String {
        switch scope {
        case .tasksAndEvents: "search.hint"
        case .tasks: "search.hint.tasks"
        case .habits: "search.hint.habits"
        case .settings: "search.hint.settings"
        case .archive: "search.hint.archive"
        case .trash: "search.hint.trash"
        case .list: "search.hint.list"
        }
    }

    /// The bar's middle has the room its sizing leaves between Back and the X: the field takes all of it.
    private var fieldWidth: CGFloat? {
        guard width > 0 else { return nil }
        return max(width - 2 * (tokens.bar(.barSideInset) + tokens.bar(.uprightBarButton) + tokens.space(.iconTextGap)), 0)
    }

    /// What the field looks through, said in it while it is empty.
    private var prompt: String {
        switch scope {
        case .tasksAndEvents: L10n.string("search.prompt")
        case .tasks: L10n.string("search.prompt.tasks")
        case .habits: L10n.string("search.prompt.habits")
        case .settings: L10n.string("search.prompt.settings")
        case .archive: L10n.string("search.prompt.archive")
        case .trash: L10n.string("search.prompt.trash")
        case .list(let id): L10n.format("search.prompt.list", L10n.string(model.config.lists.list(id)?.title ?? "lists.title"))
        }
    }
}

/// The search page's field in the bar: glass as tall as the bar's buttons, the magnifier, the text, what it looks through
/// while empty. The keyboard comes up once the page is in (`SearchKeyboard`).
private struct SearchBarField: View {
    @Environment(\.tokens) private var tokens
    @Environment(\.icons) private var icons
    @Binding var text: String
    let prompt: String
    let focus: SearchFieldFocus

    var body: some View {
        HStack(spacing: tokens.space(.iconTextGap)) {
            Image(systemName: icons[.search]).foregroundStyle(tokens.color(.secondaryText))
            SearchTextField(text: $text, prompt: prompt, focus: focus, font: tokens.uiFont(.rowTitle),
                              promptColor: tokens.uiColor(.secondaryText), tint: tokens.uiColor(.accent))
                .accessibilityIdentifier("search.field")
        }
        .padding(.horizontal, tokens.space(.searchFieldInset))
        .frame(maxHeight: .infinity)
        // Glass, as the bar's buttons beside it and the banners.
        .systemLook(.floatingCapsule)
    }
}

/// The search page's text field, so the page can give it the focus.
@MainActor
final class SearchFieldFocus {
    weak var field: UITextField?
}

/// A plain UIKit text field (the bar's middle takes it at the width given).
private struct SearchTextField: UIViewRepresentable {
    @Binding var text: String
    let prompt: String
    let focus: SearchFieldFocus
    let font: UIFont
    let promptColor: UIColor
    let tint: UIColor

    func makeUIView(context: Context) -> UITextField {
        let field = UITextField()
        field.font = font
        field.tintColor = tint
        field.returnKeyType = .search
        field.autocorrectionType = .no
        field.clearButtonMode = .never
        field.setContentHuggingPriority(.defaultLow, for: .horizontal)
        field.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        field.addTarget(context.coordinator, action: #selector(Coordinator.changed(_:)), for: .editingChanged)
        field.delegate = context.coordinator
        focus.field = field
        return field
    }

    func updateUIView(_ field: UITextField, context: Context) {
        if field.text != text { field.text = text }
        field.attributedPlaceholder = NSAttributedString(string: prompt, attributes: [.foregroundColor: promptColor, .font: font])
    }

    func makeCoordinator() -> Coordinator { Coordinator(text: $text) }

    final class Coordinator: NSObject, UITextFieldDelegate {
        let text: Binding<String>
        init(text: Binding<String>) { self.text = text }

        @objc func changed(_ field: UITextField) { text.wrappedValue = field.text ?? "" }

        func textFieldShouldReturn(_ field: UITextField) -> Bool {
            field.resignFirstResponder()
            return true
        }
    }
}

/// The keyboard of the search page: the page comes in without it, and only once it is in does the keyboard rise from
/// below (the first time only: back from a found task the keyboard stays down). Back is the system's own: the keyboard
/// leaves to the right with the page, as on every page with a field (D-195).
private struct SearchKeyboard: UIViewControllerRepresentable {
    let field: SearchFieldFocus

    func makeUIViewController(context: Context) -> Watcher { Watcher(field: field) }
    func updateUIViewController(_ controller: Watcher, context: Context) {}

    final class Watcher: UIViewController {
        let field: SearchFieldFocus
        private var focused = false

        init(field: SearchFieldFocus) {
            self.field = field
            super.init(nibName: nil, bundle: nil)
        }

        @available(*, unavailable)
        required init?(coder: NSCoder) { fatalError("init(coder:) is not used") }

        override func viewDidAppear(_ animated: Bool) {
            super.viewDidAppear(animated)
            guard !focused else { return }
            focused = true
            field.field?.becomeFirstResponder()
        }
    }
}
