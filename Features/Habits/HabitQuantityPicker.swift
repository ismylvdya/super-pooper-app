import SwiftUI

/// Until its owner commits, turning the wheel only edits this draft.
@MainActor
@Observable
final class HabitQuantityDraft {
    private let habitName: String
    private let day: LocalDate
    private let model: AppModel
    let values: [Int]
    var amount: Int
    private var submitted = false

    init(habit: TaskItem, day: LocalDate, range: HabitQuantity, model: AppModel) {
        habitName = habit.name
        self.day = day
        self.model = model
        let values = range.values
        self.values = values
        let saved = habit.quantityEntry(on: day)?.amount
        amount = values.first { $0 >= (saved ?? HabitQuantity.minimum) } ?? range.maximum
    }

    func commit() {
        guard !submitted else { return }
        submitted = true
        let selected = amount
        Task { await model.setHabitQuantity(habitName, on: day, to: selected) }
    }
}

struct HabitQuantityPicker: View {
    @State private var draft: HabitQuantityDraft
    private let commitsOnDisappear: Bool

    init(habit: TaskItem, day: LocalDate, range: HabitQuantity, model: AppModel) {
        self.init(draft: HabitQuantityDraft(habit: habit, day: day, range: range, model: model), commitsOnDisappear: true)
    }

    init(draft: HabitQuantityDraft, commitsOnDisappear: Bool) {
        _draft = State(initialValue: draft)
        self.commitsOnDisappear = commitsOnDisappear
    }

    var body: some View {
        @Bindable var draft = draft
        Picker("habitPage.quantity.amount", selection: $draft.amount) {
            ForEach(draft.values, id: \.self) { value in
                Text(value, format: .number).tag(value)
            }
        }
        .labelsHidden()
        .pickerStyle(.wheel)
        .fixedSize(horizontal: false, vertical: true)
        .onDisappear { if commitsOnDisappear { draft.commit() } }
    }
}
