import SwiftUI

/// Menu buttons for an item, taken from the action registry; only actions that make sense for the item's current state
/// and the task store are shown (`AppModel.menuEntries`).
struct ActionMenuContent: View {
    @Environment(AppModel.self) private var model
    @Environment(\.actions) private var actions
    let menu: ActionMenu
    let item: DayItem?
    /// Skip today and Not today only make sense on today's page.
    var isToday = true
    let perform: (ActionDefinition) -> Void

    var body: some View {
        ForEach(model.menuEntries(menu, for: item, isToday: isToday), id: \.action.id) { entry in
            let action = entry.action
            Button(role: action.destructive ? .destructive : nil) {
                Haptics.play(action.haptic)
                perform(action)
            } label: {
                // Habit menus show the habit marks, as the habit notifications do.
                ActionLabel(action: action, markIcon: actions.menus[menu].habitMarks ? HabitMarkIcon.icon(for: action.id) : nil)
            }
            .disabled(entry.isCurrent)
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
            isPresented: Binding(presenting: $pending),
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
