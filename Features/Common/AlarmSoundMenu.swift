import SwiftUI

/// The one menu an alarm's sound is chosen in, for a task, a habit and the settings' default: Off where it may be turned off
/// here, the default, Vibrate only and, past a divider, Choose with every other sound. Each pick plays the sound; tapping the
/// sound that is playing stops it and changes nothing.
struct AlarmSoundMenu<MenuLabel: View>: View {
    @Environment(AppModel.self) private var model
    @Environment(\.rules) private var rules
    @Environment(\.icons) private var icons
    /// What rings: nil = the default.
    let selected: String?
    /// False while the alarm is off: nothing is chosen in the menu then.
    var isOn = true
    /// What the Default item stands for and chooses: the settings' sound for an item (nil, it follows them); the sound
    /// the app ships with in the settings themselves.
    var defaultChoice: String?
    /// Off comes first when given (habits and repeatable tasks).
    var onOff: (() -> Void)?
    let onChoose: (String?) -> Void
    @ViewBuilder let label: () -> MenuLabel

    var body: some View {
        Menu {
            if let onOff { Button("alarm.off", action: onOff) }
            item(defaultChoice, title: L10n.format("alarm.sound.defaultNamed", model.alarmSoundTitle(defaultSound)))
            item(rules.alarms.vibrateSound, title: model.alarmSoundTitle(rules.alarms.vibrateSound))
            Divider()
            Menu("alarm.sound.choose") {
                ForEach(model.alarmSounds.filter { $0.id != rules.alarms.vibrateSound }, id: \.id) { sound in
                    item(sound.id, title: L10n.string(sound.title))
                }
            }
        } label: {
            label()
        }
        .menuOrder(.fixed)
        .onDisappear { AlarmSoundPreview.stop() }
    }

    private var defaultSound: String { defaultChoice ?? model.settings.notifications.alarmSound }

    private func item(_ id: String?, title: String) -> some View {
        Button { pick(id) } label: {
            if isOn, selected == id { Label(title, systemImage: icons[.chosen]) } else { Text(verbatim: title) }
        }
    }

    private func pick(_ id: String?) {
        let sound = id ?? defaultSound
        let file = model.alarmSounds.first { $0.id == sound }?.file
        if isOn, selected == id, AlarmSoundPreview.isPlaying(file) { return AlarmSoundPreview.stop() }
        onChoose(id)
        Task {
            await model.prepareAlarmSound(sound)
            if sound == rules.alarms.vibrateSound { AlarmSoundPreview.vibrate() } else { AlarmSoundPreview.play(file) }
        }
    }
}

extension AlarmSoundMenu where MenuLabel == AlarmSoundValue {
    /// As a row's value: the sound's name and the chevrons a picker has.
    init(selected: String?, defaultChoice: String? = nil, onOff: (() -> Void)? = nil, shown: String, onChoose: @escaping (String?) -> Void) {
        self.init(selected: selected, defaultChoice: defaultChoice, onOff: onOff, onChoose: onChoose) { AlarmSoundValue(shown: shown) }
    }
}

/// The chosen sound's name in a row.
struct AlarmSoundValue: View {
    @Environment(\.icons) private var icons
    @Environment(\.tokens) private var tokens
    let shown: String

    var body: some View {
        HStack(spacing: tokens.space(.valueChevronGap)) {
            Text(verbatim: shown).lineLimit(1)
            Image(systemName: icons[.menuChevrons]).imageScale(.small)
        }
        // The room a system picker leaves at its end: the values of a plate stand on one line.
        .padding(.trailing, tokens.space(.menuValueInset))
    }
}
