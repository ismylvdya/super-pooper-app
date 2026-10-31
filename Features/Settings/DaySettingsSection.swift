import SwiftUI

/// Day boundary and energy hour.
struct DaySettingsSection: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        PlateSection(header: "settings.day", hint: "settings.day.hint") {
            PlateRow(icon: .dayBoundary, title: "settings.day.boundary", info: "info.settings.day.boundary") {
                TimeField(time: Binding(get: { model.settings.day.boundary },
                                        set: { value in model.updateSettings { $0.day.boundary = value } }),
                          on: model.context().today)
                .labelsHidden()
            }
            PlateRow(icon: .energyHour, title: "settings.day.energyHour", info: "info.settings.day.energyHour") {
                TimeField(time: Binding(get: { model.settings.day.energyHour },
                                        set: { value in model.updateSettings { $0.day.energyHour = value } }),
                          on: model.context().today)
                .labelsHidden()
            }
        }
    }
}
