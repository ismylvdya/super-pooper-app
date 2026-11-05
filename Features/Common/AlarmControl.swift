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
        AlarmSoundMenu(selected: alarm?.sound, isOn: alarm != nil, onOff: { onChange(nil) }, onChoose: choose) {
            Image(systemName: icons[alarm == nil ? .alarm : .alarmOn])
                .foregroundStyle(tokens.color(alarm == nil ? .secondaryText : .accent))
        }
        .accessibilityLabel(Text("alarm.title"))
        .accessibilityIdentifier("alarm.control")
        .alert("alarm.refused.title", isPresented: $isRefused) {
            Button("common.done") {}
        } message: {
            Text("alarm.refused.message")
        }
    }

    private func choose(_ sound: String?) {
        Task {
            if await model.requestAlarmAccess() { onChange(TimeAlarm(time: time, sound: sound)) } else { isRefused = true }
        }
    }
}
