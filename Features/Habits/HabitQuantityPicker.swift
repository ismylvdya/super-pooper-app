import SwiftUI

/// The wheel holds a draft. Closing its popover is the only event that submits it.
struct HabitQuantityPicker: View {
    let habitName: String
    let day: LocalDate
    let model: AppModel
    private let values: [Int]
    @State private var amount: Int
    @State private var submitted = false

    init(habit: TaskItem, day: LocalDate, range: HabitQuantity, model: AppModel) {
        habitName = habit.name
        self.day = day
        self.model = model
        let values = range.values
        self.values = values
        let saved = habit.quantityEntry(on: day)?.amount
        _amount = State(initialValue: values.first { $0 >= (saved ?? HabitQuantity.minimum) } ?? range.maximum)
    }

    var body: some View {
        Picker("habitPage.quantity.amount", selection: $amount) {
            ForEach(values, id: \.self) { value in
                Text(value, format: .number).tag(value)
            }
        }
        .labelsHidden()
        .pickerStyle(.wheel)
        .fixedSize(horizontal: false, vertical: true)
        .onDisappear {
            guard !submitted else { return }
            submitted = true
            let selected = amount
            Task { await model.setHabitQuantity(habitName, on: day, to: selected) }
        }
        .presentationCompactAdaptation(.popover)
    }
}
