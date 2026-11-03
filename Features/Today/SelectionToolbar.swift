import SwiftUI

/// The bar of the pool's Select mode, in place of Today's own buttons: leading Cancel; trailing the selection menu's
/// frequent actions as buttons (Done, Delete) and its rarer ones in the system "…" menu (`actions.json` → `selection`).
/// A button the picked tasks cannot take is dimmed; the menu lists only what they can. Lying sideways (`bottom` set)
/// Cancel is an icon and the buttons stand in their physical left-to-right order.
struct SelectionToolbar: View {
    enum Placement { case leading, trailing }

    private enum Item: Hashable {
        case action(ActionID)
        case more
    }

    @Environment(AppModel.self) private var model
    @Environment(\.tokens) private var tokens
    @Environment(\.icons) private var icons
    @Environment(\.actions) private var actions
    let placement: Placement
    let selection: PoolSelection
    let day: LocalDate
    var bottom: HorizontalEdge?
    let perform: (ActionDefinition) -> Void

    var body: some View {
        switch placement {
        case .leading: cancel
        case .trailing: trailing
        }
    }

    private var cancel: some View {
        Button { selection.end() } label: {
            if bottom == nil { Text("common.cancel") } else { Image(systemName: icons[.selectCancel]) }
        }
        .tint(tokens.color(.accent))
        .modifier(ColumnButton(isInColumn: bottom != nil))
        .accessibilityLabel(Text("common.cancel"))
        .accessibilityIdentifier("select.cancel")
    }

    @ViewBuilder private var trailing: some View {
        let entries = model.selectionEntries(for: selection.names, on: day)
        let buttons = actions.menus[.selection].frequent.map(actions.definition).filter { !model.needsConfirmation($0) }
        let items = buttons.map { Item.action($0.id) } + [.more]
        ForEach(PhysicalBottom.physicalOrder(items, bottom: bottom), id: \.self) { item in
            switch item {
            case .action(let id):
                let action = actions.definition(id)
                button(action, isOffered: entries.frequent.contains(action))
            case .more:
                more(entries.more)
            }
        }
    }

    private func button(_ action: ActionDefinition, isOffered: Bool) -> some View {
        Button {
            Haptics.play(action.haptic)
            perform(action)
        } label: {
            Image(systemName: action.icon)
        }
        .tint(action.destructive ? tokens.color(.destructive) : tokens.color(.accent))
        .disabled(!isOffered)
        .modifier(ColumnButton(isInColumn: bottom != nil))
        .accessibilityLabel(Text(LocalizedStringKey(action.title)))
        .accessibilityIdentifier("select.\(action.id.rawValue)")
    }

    private func more(_ actions: [ActionDefinition]) -> some View {
        Menu {
            ForEach(actions, id: \.id) { action in
                Button(role: action.destructive ? .destructive : nil) {
                    Haptics.play(action.haptic)
                    perform(action)
                } label: {
                    ActionLabel(action: action)
                }
                .accessibilityIdentifier("action.\(action.id.rawValue)")
            }
        } label: {
            Image(systemName: icons[.more])
        }
        .tint(tokens.color(.accent))
        .disabled(actions.isEmpty)
        .modifier(ColumnButton(isInColumn: bottom != nil))
        .accessibilityLabel(Text("select.more"))
        .accessibilityIdentifier("select.more")
    }
}

/// Lying sideways each button takes the size of a system bar button in its bubble, as Today's own do.
private struct ColumnButton: ViewModifier {
    @Environment(\.tokens) private var tokens
    let isInColumn: Bool

    func body(content: Content) -> some View {
        if isInColumn {
            content
                .frame(minWidth: tokens.bar(.barButton), minHeight: tokens.bar(.barButton))
                .contentShape(Capsule())
        } else {
            content
        }
    }
}
