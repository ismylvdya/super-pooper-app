import SwiftUI

/// In a form, under a time: a switch for the alarm and, while it is on, its sound. Switching it on asks the system's
/// permission; refused, it stays off and says where to allow it.
struct AlarmRows: View {
    @Environment(AppModel.self) private var model
    @Binding var alarm: TimeAlarm?
    /// A repeatable task's sound menu also turns the alarm off.
    var offersOff = false
    @State private var isRefused = false

    var body: some View {
        SwitchToggle("alarm.title", isOn: Binding(get: { alarm != nil }, set: setOn))
            .accessibilityIdentifier("duePicker.alarm")
            .alert("alarm.refused.title", isPresented: $isRefused) {
                Button("common.ok") {}
            } message: {
                Text("alarm.refused.message")
            }
        if let alarm {
            LabeledContent("alarm.sound") {
                AlarmSoundMenu(selected: alarm.sound, onOff: offersOff ? { self.alarm = nil } : nil, shown: alarm.sound.map(model.alarmSoundTitle) ?? L10n.string("alarm.sound.default")) { self.alarm?.sound = $0 }
                    .accessibilityIdentifier("duePicker.alarmSound")
            }
            .childRow()
        }
    }

    private func setOn(_ isOn: Bool) {
        guard isOn else {
            alarm = nil
            return
        }
        Task {
            if await model.requestAlarmAccess() { alarm = TimeAlarm() } else { isRefused = true }
        }
    }

}
