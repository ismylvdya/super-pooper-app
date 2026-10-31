import SwiftUI

/// Long-press menu of a habit's day, the same as a habit's menu in the pool (`actions.json` → `habitDay`): the
/// marks with their images, the current one not selectable. In the history the day is named ("17 Sep 2026").
struct HabitDayMenu: View {
    @Environment(AppModel.self) private var model
    let habit: TaskNote
    let day: LocalDate
    var showsDate = false

    var body: some View {
        if showsDate {
            Text(DateText.format(day, .dateTime.day().month(.abbreviated).year(), calendar: model.calendar))
        }
        let state = HabitInstances(task: habit).mark(on: day).map(DayItemState.marked) ?? .open
        ActionMenuContent(menu: .habitDay, item: DayItem(task: habit, state: state, blockers: [], problems: [])) { action in
            Task { await model.setHabitMark(habit.name, on: day, to: AppModel.habitMark(for: action.id)) }
        }
    }
}
