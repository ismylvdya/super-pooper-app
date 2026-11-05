import SwiftUI

/// The zone a habit's times are kept in: None (the phone's clock, the default) or a zone picked from the list — then
/// 09:00 means 09:00 there, wherever the phone is (`ZonedTimes`). Shown only for an item with a time. A task picks its
/// zone on the date sheet (`DuePickerSheet`).
struct TimeZoneRow: View {
    @Environment(\.tokens) private var tokens
    @Environment(AppModel.self) private var model
    let editor: TaskEditor
    @State private var isPicking = false

    var body: some View {
        let task = editor.task
        if task.due?.time != nil || !task.reminderTimes.isEmpty {
            PlateRow(icon: .timeZone, title: "taskPage.timeZone", info: "info.taskPage.timeZone") {
                Button { isPicking = true } label: {
                    Text(TimeZonePicker.title(of: task.timeZone, at: model.clock.now))
                        .foregroundStyle(tokens.color(.secondaryText))
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("taskPage.timeZone")
            }
            .sheet(isPresented: $isPicking) {
                NavigationStack {
                    TimeZonePicker(selected: task.timeZone) { zone in editor.apply([.timeZone(zone)]) }
                }
            }
        }
    }
}
