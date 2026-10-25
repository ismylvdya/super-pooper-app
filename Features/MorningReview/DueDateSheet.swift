import SwiftUI

/// The system date (and optional time) picker for a task date.
struct DueDateSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppModel.self) private var model
    @Environment(\.tokens) private var tokens
    @State private var date: Date
    @State private var hasTime: Bool
    let onSave: (TaskDue?) -> Void

    init(due: TaskDue, calendar: Calendar, onSave: @escaping (TaskDue?) -> Void) {
        _date = State(initialValue: due.date(in: calendar))
        _hasTime = State(initialValue: due.time != nil)
        self.onSave = onSave
    }

    var body: some View {
        NavigationStack {
            Form {
                DatePicker("taskPage.due.date", selection: $date, displayedComponents: .date)
                    .datePickerStyle(.graphical)
                Toggle("taskPage.due.hasTime", isOn: $hasTime)
                if hasTime {
                    DatePicker("taskPage.due.time", selection: $date, displayedComponents: .hourAndMinute)
                }
            }
            .navigationTitle(Text("review.due.exact"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("common.cancel") { dismiss() } }
                ToolbarItem(placement: .destructiveAction) {
                    Button("review.due.clear") {
                        onSave(nil)
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("common.save") {
                        let time = hasTime ? LocalTime(date, in: model.calendar) : nil
                        onSave(TaskDue(day: LocalDate(date, in: model.calendar), time: time))
                        dismiss()
                    }
                    .font(tokens.font(.emptyAction))
                }
            }
        }
        .presentationDetents([.large])
    }
}
