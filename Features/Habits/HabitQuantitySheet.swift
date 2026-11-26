import SwiftUI

struct HabitQuantityRequest: Identifiable, Hashable {
    let habitName: String
    let day: LocalDate
    var id: Self { self }
}

struct HabitQuantitySheet: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    let request: HabitQuantityRequest
    private let values: [Int]
    private let entry: HabitQuantityEntry?
    @State private var amount: Int

    init(request: HabitQuantityRequest, habit: TaskItem, range: HabitQuantity) {
        self.request = request
        let entry = habit.quantityEntry(on: request.day)
        self.entry = entry
        let values = range.values
        self.values = values
        _amount = State(initialValue: values.first { $0 >= (entry?.amount ?? 1) } ?? range.maximum)
    }

    var body: some View {
        NavigationStack {
            VStack {
                Text(DateText.format(request.day, .dateTime.day().month(.abbreviated).year(), calendar: model.calendar))
                    .foregroundStyle(.secondary)
                Picker("habitPage.quantity.amount", selection: $amount) {
                    ForEach(values, id: \.self) { value in
                        Text(value, format: .number).tag(value)
                    }
                }
                .pickerStyle(.wheel)
                HStack {
                    Button("action.partial") {
                        submit { await model.setHabitMark(request.habitName, on: request.day, to: .partial) }
                    }
                    .disabled(entry == .partial)
                    Spacer()
                    Button("action.unmark") {
                        submit { await model.setHabitQuantity(request.habitName, on: request.day, to: nil) }
                    }
                    .disabled(entry == nil)
                }
                .padding(.horizontal)
            }
            .navigationTitle(request.habitName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("common.cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("common.save") {
                        let selected = amount
                        submit { await model.setHabitQuantity(request.habitName, on: request.day, to: selected) }
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    private func submit(_ change: @escaping @MainActor () async -> Void) {
        Haptics.play(.mark)
        dismiss()
        Task { await change() }
    }
}
