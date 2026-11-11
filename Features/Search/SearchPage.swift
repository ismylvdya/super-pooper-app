import SwiftUI
import UIKit

/// The one search of the app, a page of its own opened from a page's "…" or a hold of its title: Back on the left, the
/// field in the middle saying what it looks through (`SearchScope`), on the right an X that empties the field — dim
/// while there is nothing in it. Under it the page's own rows that match: Today's and the Lists page's every task (and
/// Today's events), a tab's, a list's, the archive's and the trash's own.
struct SearchPage: View {
    @Environment(AppModel.self) private var model
    @Environment(\.tokens) private var tokens
    @Environment(\.icons) private var icons
    let scope: SearchScope
    @State private var query = ""
    @State private var width: CGFloat = 0

    var body: some View {
        results
            .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { width = $0 }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    SearchBarField(text: $query, prompt: prompt).frame(width: fieldWidth, height: tokens.bar(.searchField))
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

    @ViewBuilder private var results: some View {
        switch scope {
        case .tasksAndEvents: TaskSearchResults(withEvents: true, query: query)
        case .tasks: TaskSearchResults(withEvents: false, query: query)
        case .habits: HabitsScreen(searchQuery: query)
        case .settings: SettingsScreen(searchQuery: query)
        case .archive: ArchiveScreen(searchQuery: query)
        case .trash: TrashScreen(searchQuery: query)
        case .list(let id): TaskListScreen(listID: id, searchQuery: query)
        case .customList(let title): TaskListScreen(listID: "", custom: title, searchQuery: query)
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
        case .customList(let title): L10n.format("search.prompt.list", title)
        }
    }
}

/// The search page's field in the bar: the magnifier, the text, what it looks through while empty. The keyboard comes up
/// with the page: the field takes the focus itself once it is in the window, which a SwiftUI focus set during the push
/// does not reach.
private struct SearchBarField: View {
    @Environment(\.tokens) private var tokens
    @Environment(\.icons) private var icons
    @Binding var text: String
    let prompt: String

    var body: some View {
        HStack(spacing: tokens.space(.iconTextGap)) {
            Image(systemName: icons[.search]).foregroundStyle(tokens.color(.secondaryText))
            FocusingTextField(text: $text, prompt: prompt, font: tokens.uiFont(.rowTitle),
                              promptColor: tokens.uiColor(.secondaryText), tint: tokens.uiColor(.accent))
                .accessibilityIdentifier("search.field")
        }
        .padding(.horizontal, tokens.space(.searchFieldInset))
        .frame(maxHeight: .infinity)
        .background(tokens.color(.plateBackground), in: Capsule())
    }
}

/// A plain text field that becomes the first responder as soon as it is shown.
private struct FocusingTextField: UIViewRepresentable {
    @Binding var text: String
    let prompt: String
    let font: UIFont
    let promptColor: UIColor
    let tint: UIColor

    func makeUIView(context: Context) -> Field {
        let field = Field()
        field.font = font
        field.tintColor = tint
        field.returnKeyType = .search
        field.autocorrectionType = .no
        field.clearButtonMode = .never
        field.setContentHuggingPriority(.defaultLow, for: .horizontal)
        field.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        field.addTarget(context.coordinator, action: #selector(Coordinator.changed(_:)), for: .editingChanged)
        field.delegate = context.coordinator
        return field
    }

    func updateUIView(_ field: Field, context: Context) {
        if field.text != text { field.text = text }
        field.attributedPlaceholder = NSAttributedString(string: prompt, attributes: [.foregroundColor: promptColor, .font: font])
    }

    func makeCoordinator() -> Coordinator { Coordinator(text: $text) }

    final class Field: UITextField {
        override func didMoveToWindow() {
            super.didMoveToWindow()
            guard window != nil else { return }
            DispatchQueue.main.async { [weak self] in self?.becomeFirstResponder() }
        }
    }

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
