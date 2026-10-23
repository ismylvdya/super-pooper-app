import SwiftUI

/// The system date (and optional time) picker for a task date.
struct DueDateSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppModel.self) private var model
    @State private var date: Date
    @State private var hasTime: Bool
    let onSave: (TaskDue?) -> Void

    init(due: TaskDue, onSave: @escaping (TaskDue?) -> Void) {
        var calendar = Calendar.current
        calendar.timeZone = .current
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
                        let parts = model.calendar.dateComponents([.hour, .minute], from: date)
                        let time = hasTime ? LocalTime(hour: parts.hour ?? 0, minute: parts.minute ?? 0) : nil
                        onSave(TaskDue(day: LocalDate(date, in: model.calendar), time: time))
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
        .presentationDetents([.large])
    }
}
