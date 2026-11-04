import SwiftUI

/// In a form, under a time: a switch for the alarm and, while it is on, its sound. Switching it on asks the system's
/// permission; refused, it stays off and says where to allow it.
struct AlarmRows: View {
    @Environment(AppModel.self) private var model
    @Environment(\.rules) private var rules
    @Binding var alarm: TimeAlarm?
    @State private var isRefused = false

    var body: some View {
        Toggle("alarm.title", isOn: Binding(get: { alarm != nil }, set: setOn))
            .accessibilityIdentifier("duePicker.alarm")
            .alert("alarm.refused.title", isPresented: $isRefused) {
                Button("common.done") {}
            } message: {
                Text("alarm.refused.message")
            }
        if let alarm {
            Picker("alarm.sound", selection: Binding(get: { alarm.sound }, set: choose)) {
                Text("alarm.sound.default").tag(String?.none)
                ForEach(model.alarmSounds, id: \.id) { sound in
                    Text(verbatim: L10n.string(sound.title)).tag(String?.some(sound.id))
                }
            }
            .accessibilityIdentifier("duePicker.alarmSound")
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

    private func choose(_ sound: String?) {
        alarm?.sound = sound
        Task {
            await model.prepareAlarmSound(sound)
            AlarmSoundPreview.play(model.alarmSounds.first { $0.id == sound }?.file, seconds: rules.alarms.previewSeconds)
        }
    }
}
