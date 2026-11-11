import SwiftUI

/// Where a task can go, as the entries of a menu: its statuses. `current` is ticked.
struct StatusChoiceMenu: View {
    let levels: [TaskStatus]
    var current: TaskStatus?
    let onPick: (TaskStatus) -> Void

    var body: some View {
        ForEach(levels, id: \.self) { status in choice(status) }
    }

    @ViewBuilder private func choice(_ status: TaskStatus) -> some View {
        if let current {
            Toggle(isOn: Binding(get: { current == status }, set: { _ in onPick(status) })) { StatusLabel(status: status) }
        } else {
            Button { onPick(status) } label: { StatusLabel(status: status) }
        }
    }
}

/// A status's name with its icon (Settings → Lists for the icons).
struct StatusLabel: View {
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
