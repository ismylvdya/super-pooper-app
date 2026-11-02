import SwiftUI

/// Menu buttons for an item, taken from the action registry; only actions that make sense for the item's current state
/// and the task store are shown (`AppModel.menuEntries`). The rarer ones stand in their own section under the frequent ones.
struct ActionMenuContent: View {
    @Environment(AppModel.self) private var model
    @Environment(\.actions) private var actions
    let menu: ActionMenu
    let item: DayItem?
    /// Skip today and Not today only make sense on today's page.
    var isToday = true
    let perform: (ActionDefinition) -> Void

    var body: some View {
        let entries = model.menuEntries(menu, for: item, isToday: isToday)
        MenuSections(frequent: entries.filter { !$0.isMore }, more: entries.filter(\.isMore)) { button($0) }
    }

    private func button(_ entry: MenuEntry) -> some View {
        let action = entry.action
        return Button(role: action.destructive ? .destructive : nil) {
            Haptics.play(action.haptic)
            perform(action)
        } label: {
            // Habit menus show the habit marks, as the habit notifications do.
            ActionLabel(action: action, markIcon: actions.menus[menu].habitMarks ? HabitMarkIcon.icon(for: action.id) : nil)
        }
        .disabled(entry.isCurrent)
        .accessibilityIdentifier("action.\(action.id.rawValue)")
    }
}
