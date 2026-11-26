import SwiftUI

/// Long-press menu of a habit's day, the same as a habit's menu in the pool (`actions.json` → `habitDay`): the
/// marks with their images, the current one not selectable, and on today Skip today. In the history the day is named
/// ("17 Sep 2026").
struct HabitDayMenu: View {
    @Environment(AppModel.self) private var model
    let habit: TaskItem
    let day: LocalDate
    var showsDate = false

    var body: some View {
        if showsDate {
            Text(DateText.format(day, .dateTime.day().month(.abbreviated).year(), calendar: model.calendar))
        }
        ActionMenuContent(menu: .habitDay, item: DayItem(habit: habit, on: day), isToday: day == model.context().today) { action in
            Task {
                if action.id.setsHabitMark {
                    await model.setHabitMark(habit.name, on: day, to: action.id.habitMark)
                } else {
                    await model.performOfferingUndo(action, on: habit.name)
                }
            }
        }
    }
}
