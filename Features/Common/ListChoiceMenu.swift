import SwiftUI

/// Where a task can go, as the entries of a menu: the planning levels, then under a divider the user's own lists and
/// New list (the title is asked for by `newListAlert`). `current` is ticked.
struct ListChoiceMenu: View {
    @Environment(AppModel.self) private var model
    @Environment(\.icons) private var icons
    let levels: [TaskStatus]
    var current: TaskStatus?
    let onPick: (TaskStatus) -> Void
    let onNew: () -> Void

    var body: some View {
        ForEach(levels, id: \.self) { status in choice(status) }
        Divider()
        ForEach(model.customLists, id: \.self) { title in choice(.custom(title)) }
        Button(action: onNew) { Label("lists.new", systemImage: icons[.newList]) }
            .accessibilityIdentifier("lists.new")
    }

    @ViewBuilder private func choice(_ status: TaskStatus) -> some View {
        if let current {
            Toggle(isOn: Binding(get: { current == status }, set: { _ in onPick(status) })) { ListLabel(status: status) }
        } else {
            Button { onPick(status) } label: { ListLabel(status: status) }
        }
    }
}

/// A list's name with its icon (Settings → Lists for the planning levels).
struct ListLabel: View {
    @Environment(AppModel.self) private var model
    @Environment(\.tokens) private var tokens
    @Environment(\.icons) private var icons
    @Environment(\.displayScale) private var displayScale
    let status: TaskStatus

    var body: some View {
        Label {
            Text(StatusText.title(status))
        } icon: {
            let list = TaskListIcons(icons: icons, typed: model.settings.lists.symbols)
            TabIconImage.image(list.symbol(of: status), font: .preferredFont(forTextStyle: .body), others: list.symbols(besides: status),
                               fit: tokens.bar(.tabGlyphFit), scale: displayScale)
        }
    }
}

extension View {
    /// Asks for a new list's title; Create is offered once the title is one a new list may take (`AppModel.newListTitle`).
    func newListAlert(isPresented: Binding<Bool>, onCreate: @escaping (String) -> Void) -> some View {
        modifier(NewListPrompt(isPresented: isPresented, onCreate: onCreate))
    }
}

private struct NewListPrompt: ViewModifier {
    @Environment(AppModel.self) private var model
    @Binding var isPresented: Bool
    let onCreate: (String) -> Void

    func body(content: Content) -> some View {
        content.namePrompt(.list, isPresented: $isPresented, accepts: model.newListTitle, onCreate: onCreate)
    }
}
