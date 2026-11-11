import SwiftUI

/// One table row: title and editable chips: High, date, estimate, energy,
/// pleasant, status.
struct ReviewRow: View {
    @Environment(AppModel.self) private var model
    @Environment(\.tokens) private var tokens
    @Environment(\.icons) private var icons
    @Environment(\.rules) private var rules
    let item: DayItem
    let today: LocalDate
    let onOpen: () -> Void
    @State private var isPickingDate = false

    private var task: TaskItem { item.task }

    var body: some View {
        VStack(alignment: .leading, spacing: tokens.space(.chipGap)) {
            HStack(spacing: tokens.space(.chipGap)) {
                if item.isHabit { Image(systemName: icons[ChipLook.habit.icon]).foregroundStyle(tokens.color(of: .habit)) }
                ParentCaption(parent: item.project) {
                    Text(task.name).font(tokens.font(.taskTitle)).foregroundStyle(item.isDone ? tokens.color(.secondaryText) : tokens.color(.primaryText))
                }
            }
            ChipFlow(spacing: tokens.space(.chipGap)) {
                toggleChip(.high, isOn: task.isHighPriority) { [.highPriority(!$0.isHighPriority)] }
                dueChip
                estimateChip
                // One feel: turning one on turns the other off.
                toggleChip(.needEnergy, isOn: task.feel == .needEnergy) { [.feel($0.feel == .needEnergy ? .neutral : .needEnergy)] }
                toggleChip(.pleasant, isOn: task.feel == .pleasant) { [.feel($0.feel == .pleasant ? .neutral : .pleasant)] }
                if !task.isHabit { statusChip }
            }
        }
        .padding(.vertical, tokens.space(.reviewRowVertical))
        .padding(.trailing, tokens.size(.reviewChevron))
        .frame(maxWidth: .infinity, alignment: .leading)
        .overlay(alignment: .trailing) { DisclosureAccessory() }
        .contentShape(Rectangle())
        .onTapGesture(perform: onOpen)
    }

    /// The new value is decided from the note as it is when the edit runs (two quick taps go there and back).
    private func toggleChip(_ look: ChipLook, isOn: Bool, changes: @escaping (TaskItem) -> [TaskEdit]) -> some View {
        ToggleChip(look, isOn: isOn, capsule: .standard) {
            Haptics.play(.select)
            Task { await model.edit(task.name, changes) }
        }
    }

    /// Today / Tomorrow / an exact date and time; the chosen one is checked, choosing it again
    /// removes the date (no option checked = no date). Today and Tomorrow are logical days, as the task page's chips.
    private var dueChip: some View {
        let context = model.context()
        let selected = QuickDue.selection(of: task.due, context: context)
        return Menu {
            ForEach(QuickDue.allCases, id: \.self) { chip in
                Toggle(chip.title, isOn: Binding(
                    get: { selected == chip },
                    set: { _ in setDue(QuickDue.toggling(chip, due: task.due, context: context)) }
                ))
            }
            Toggle("review.due.exact", isOn: Binding(get: { task.due != nil && selected == nil },
                                                    set: { _ in isPickingDate = true }))
        } label: {
            Chip(icon: .due, text: task.due.map { DueText.format($0, context: context) }, isOn: task.due != nil)
        }
        .sheet(isPresented: $isPickingDate) {
            let due = task.due ?? TaskDue(day: today, time: rules.editing.defaultTime)
            DuePickerSheet(pick: DuePick(day: due.day, time: due.time), choosesZone: false) { setDue($0?.due) }
        }
    }

    /// The row shows the day's view of the task (times on the phone's clock); the model writes it back in the note's zone.
    private func setDue(_ due: TaskDue?) {
        Task { await model.setLocalDue(due, of: task.name) }
    }

    private var estimateChip: some View {
        Menu {
            ForEach(rules.timeEstimates, id: \.minutes) { option in
                Button(LocalizedStringKey(option.label)) { Task { await model.update(task.name, [.timeEstimate(option.minutes)]) } }
            }
        } label: {
            Chip(icon: .estimate, text: EstimateText.label(task.timeEstimate, rules: rules))
        }
    }

    private var statusChip: some View {
        Menu {
            ForEach(TaskStatus.reviewChoices, id: \.self) { status in
                Button(StatusText.title(status)) { Task { await model.setStatus(status, of: task.name) } }
            }
        } label: {
            Chip(icon: .status, text: StatusText.title(task.status))
        }
    }
}
