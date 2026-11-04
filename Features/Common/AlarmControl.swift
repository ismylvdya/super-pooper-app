import SwiftUI

/// Beside a time: whether it rings as an alarm, and with which sound. The first alarm asks the system's permission; refused,
/// it stays off and says where to allow it.
struct AlarmControl: View {
    @Environment(AppModel.self) private var model
    @Environment(\.rules) private var rules
    @Environment(\.icons) private var icons
    @Environment(\.tokens) private var tokens
    let alarm: TimeAlarm?
    /// The alarm chosen: nil = off, otherwise its sound (nil = the settings' one).
    let onChange: (TimeAlarm?) -> Void
    /// Which time it stands by (a habit's); nil for a task.
    var time: LocalTime?
    @State private var isRefused = false

    var body: some View {
        Menu {
            Button("alarm.off") { onChange(nil) }
            Section {
                choice(nil, title: L10n.string("alarm.sound.default"))
                ForEach(model.alarmSounds, id: \.id) { sound in
                    choice(sound.id, title: L10n.string(sound.title))
                }
            }
        } label: {
            Image(systemName: icons[alarm == nil ? .alarm : .alarmOn])
                .foregroundStyle(tokens.color(alarm == nil ? .secondaryText : .accent))
        }
        .accessibilityLabel(Text("alarm.title"))
        .accessibilityIdentifier("alarm.control")
        .onDisappear { AlarmSoundPreview.stop() }
        .alert("alarm.refused.title", isPresented: $isRefused) {
            Button("common.done") {}
        } message: {
            Text("alarm.refused.message")
        }
    }

    private func choice(_ sound: String?, title: String) -> some View {
        Button {
            Task {
                if await model.requestAlarmAccess() {
                    await model.prepareAlarmSound(sound)
                    onChange(TimeAlarm(time: time, sound: sound))
                    AlarmSoundPreview.play(model.alarmSounds.first { $0.id == (sound ?? model.settings.notifications.alarmSound) }?.file)
                } else {
                    isRefused = true
                }
            }
        } label: {
            if alarm != nil, alarm?.sound == sound { Label(title, systemImage: icons[.chosen]) } else { Text(verbatim: title) }
        }
    }
}
