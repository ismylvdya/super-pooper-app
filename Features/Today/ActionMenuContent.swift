import SwiftUI

/// Menu buttons for an item, taken from the action registry; only actions that make sense
/// for the item's current state are shown.
struct ActionMenuContent: View {
    @Environment(\.actions) private var actions
    let menu: ActionMenu
    let item: DayItem?
    let perform: (ActionDefinition) -> Void

    var body: some View {
        ForEach(actions.actions(in: menu).filter(isAvailable), id: \.id) { action in
            Button(role: action.destructive ? .destructive : nil) {
                Haptics.play(action.haptic)
                perform(action)
            } label: {
                Label(LocalizedStringKey(action.title), systemImage: action.icon)
            }
        }
    }

    private func isAvailable(_ action: ActionDefinition) -> Bool {
        guard let item else { return true }
        switch action.id {
        case .done: return item.state != .marked(.done) && !item.isBlocked
        case .partial: return item.state != .marked(.partial) && !item.isBlocked
        case .twice: return item.state != .marked(.twice) && !item.isBlocked
        case .unmark: return item.isDone
        case .skipToday: return item.isHabit && !item.isDone
        default: return true
        }
    }
}

/// Shows the registry's confirmation dialog before a confirmed action runs.
struct ActionConfirmation: ViewModifier {
    @Binding var pending: PendingAction?
    let perform: (PendingAction) -> Void

    func body(content: Content) -> some View {
        content.alert(
            Text(LocalizedStringKey(pending?.action.confirmTitle ?? "")),
            isPresented: Binding(get: { pending != nil }, set: { if !$0 { pending = nil } }),
            presenting: pending
        ) { pending in
            Button(LocalizedStringKey(pending.action.title), role: pending.action.destructive ? .destructive : nil) {
                perform(pending)
            }
            Button("common.cancel", role: .cancel) {}
        } message: { pending in
            Text(L10n.format(pending.action.confirmMessage ?? "", pending.taskName))
        }
    }
}

struct PendingAction: Identifiable, Equatable {
    let action: ActionDefinition
    let taskName: String
    var id: String { "\(action.id.rawValue)|\(taskName)" }
}

extension View {
    func actionConfirmation(_ pending: Binding<PendingAction?>, perform: @escaping (PendingAction) -> Void) -> some View {
        modifier(ActionConfirmation(pending: pending, perform: perform))
    }
}
