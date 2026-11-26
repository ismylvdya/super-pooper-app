import ListEngineChumbulev
import SwiftUI

/// The action registry (`actions.json`) as the list engine's menus and swipes: the same actions a row offers now
/// (`AppModel.menuEntries`, `swipeActions`), with their titles, icons, colors and haptics, run the way the app runs
/// them (`perform`: its confirmation first, where the action asks for one).
@MainActor
struct EngineActions {
    let model: AppModel
    let tokens: DesignTokens
    let registry: ActionRegistry
    let icons: IconSet
    /// Runs an action on the task or habit of that name.
    let perform: (ActionDefinition, String) -> Void

    /// A row's menu: the frequent actions, then the rarer ones after a divider; what the row already is, greyed.
    func menu(_ menu: ActionMenu, for item: DayItem, isToday: Bool = true, poolDay: LocalDate? = nil) -> [ListAction] {
        let entries = model.menuEntries(menu, for: item, isToday: isToday, poolDay: poolDay)
        let day = poolDay ?? model.context().today
        let frequent = entries.filter { !$0.isMore }, more = entries.filter(\.isMore)
        let marks = registry.menus[menu].habitMarks
        return (frequent + more).enumerated().map { index, entry in
            let action = entry.action
            let mark = marks ? HabitMarkIcon.icon(for: action.id) : nil
            let icon = mark.map { icons[$0] } ?? action.icon
            let opacity = mark == .habitMarkOpen ? tokens.opacity(.habitOpenRing) : 1
            let child: (() -> AnyView)?
            if action.id == .setAmount, let range = item.task.habit.quantityTracking {
                child = { AnyView(HabitQuantityPicker(habit: item.task, day: day, range: range, model: model)) }
            } else {
                child = nil
            }
            return ListAction(title: L10n.string(action.title), icon: .app(icon), tone: tone(action),
                              dividerBefore: entry.isMore && index == frequent.count && !frequent.isEmpty, isEnabled: !entry.isCurrent,
                              iconOpacity: opacity, child: child) {
                Haptics.play(action.haptic)
                perform(action, item.id)
            }
        }
    }

    /// A row's swipes: on each side the action a full swipe runs (the first the row offers there).
    func swipes(_ swipes: ActionSwipes, for item: DayItem, isToday: Bool = true,
                run: ((ActionDefinition) -> Void)? = nil) -> ListSwipes {
        let actions = model.swipeActions(swipes, for: item, isToday: isToday)
        let swipe = { (action: ActionDefinition) in
            ListSwipe(title: L10n.string(action.title), icon: .app(action.icon), color: ThemeColor(tokens.uiColor(tint(of: action)))) {
                Haptics.play(action.haptic)
                if let run { run(action) } else { perform(action, item.id) }
            }
        }
        return ListSwipes(leading: actions.leading.first.map(swipe), trailing: actions.trailing.first.map(swipe))
    }

    private func tone(_ action: ActionDefinition) -> ListAction.Tone {
        if action.destructive { return .destructive }
        return action.color == nil ? .plain : .positive
    }

    private func tint(of action: ActionDefinition) -> ColorToken {
        action.swipeTint.flatMap(ColorToken.init(rawValue:)) ?? (action.destructive ? .destructive : .accent)
    }
}

extension View {
    /// The engine's theme for every list under this view.
    func appListTheme() -> some View {
        listTheme(.app)
    }
}
