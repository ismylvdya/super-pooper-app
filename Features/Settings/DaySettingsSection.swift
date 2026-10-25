import SwiftUI

/// Day boundary and energy hour.
struct DaySettingsSection: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        PlateSection(header: "settings.day", hint: "settings.day.hint") {
            PlateRow(icon: .dayBoundary, title: "settings.day.boundary", info: "info.settings.day.boundary") {
                TimeField(time: Binding(get: { model.settings.day.boundary },
                                        set: { value in model.updateSettings { $0.day.boundary = value } }))
            }
            PlateRow(icon: .energyHour, title: "settings.day.energyHour", info: "info.settings.day.energyHour") {
                TimeField(time: Binding(get: { model.settings.day.energyHour },
                                        set: { value in model.updateSettings { $0.day.energyHour = value } }))
            }
        }
    }
}

/// A compact hour-and-minute picker bound to `LocalTime`.
struct TimeField: View {
    @Environment(\.calendar) private var calendar
    @Binding var time: LocalTime

    var body: some View {
        DatePicker("", selection: Binding(
            get: { calendar.date(from: DateComponents(hour: time.hour, minute: time.minute)) ?? .distantPast },
            set: { date in time = LocalTime(date, in: calendar) }
        ), displayedComponents: .hourAndMinute)
        .labelsHidden()
    }
}
