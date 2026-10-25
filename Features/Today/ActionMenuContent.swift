import SwiftUI

/// Menu buttons for an item, taken from the action registry; only actions that make sense
/// for the item's current state are shown.
struct ActionMenuContent: View {
    @Environment(\.actions) private var actions
    @Environment(\.icons) private var icons
    let menu: ActionMenu
    let item: DayItem?
    /// Skip today and Not today only make sense on today's page.
    var isToday = true
    let perform: (ActionDefinition) -> Void

    var body: some View {
        ForEach(actions.actions(in: menu).filter(isAvailable), id: \.id) { action in
            let isCurrent = isCurrentMark(action)
            Button(role: action.destructive ? .destructive : nil) {
                Haptics.play(action.haptic)
                perform(action)
            } label: {
                // Habit menus show the habit marks, as the habit notifications do.
                if menu.isHabitMenu, let mark = HabitMarkIcon.icon(for: action.id) {
                    Label { Text(LocalizedStringKey(action.title)) } icon: { Image(icons[mark]).renderingMode(.template) }
                } else {
                    Label(LocalizedStringKey(action.title), systemImage: action.icon)
                }
            }
            .disabled(isCurrent)
        }
    }

    /// The mark the item already has: shown, but not selectable.
    private func isCurrentMark(_ action: ActionDefinition) -> Bool {
        guard let item else { return false }
        switch action.id {
        case .done: return item.state == .marked(.done)
        case .partial: return item.state == .marked(.partial)
        case .twice: return item.state == .marked(.twice)
        default: return false
        }
    }

    private func isAvailable(_ action: ActionDefinition) -> Bool {
        guard let item else { return true }
        switch action.id {
        case .done, .partial: return true
        case .twice: return !item.isHabit || item.task.habit.twiceADay || item.state == .marked(.twice)
        case .unmark: return item.isDone
        case .skipToday: return isToday && item.isHabit && !item.isDone
        case .notToday: return isToday && !item.isHabit && !item.isDone
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
