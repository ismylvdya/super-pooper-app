import SwiftUI

/// The system date (and optional time) picker for a task date. It keeps the wall-clock day and time it shows, so a
/// time zone change while it is open does not move them.
struct DueDateSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.tokens) private var tokens
    @State private var day: LocalDate
    @State private var time: LocalTime
    @State private var hasTime: Bool
    let onSave: (TaskDue?) -> Void

    init(due: TaskDue, onSave: @escaping (TaskDue?) -> Void) {
        _day = State(initialValue: due.day)
        _time = State(initialValue: due.time ?? .midnight)
        _hasTime = State(initialValue: due.time != nil)
        self.onSave = onSave
    }

    var body: some View {
        NavigationStack {
            Form {
                DayField("taskPage.due.date", day: $day)
                    .datePickerStyle(.graphical)
                Toggle("taskPage.due.hasTime", isOn: $hasTime)
                if hasTime {
                    TimeField("taskPage.due.time", time: $time, on: day)
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
                        onSave(TaskDue(day: day, time: hasTime ? time : nil))
                        dismiss()
                    }
                    .font(tokens.font(.emptyAction))
                }
            }
        }
        .presentationDetents([.large])
    }
}
