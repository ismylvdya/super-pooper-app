import SwiftUI

/// The date sheet: three switches, each opening the next. Date with its calendar, Time with its time and, where the item
/// keeps a zone, the Time zone (None unless one is chosen), then Alarm with its sound. It keeps the wall-clock day and time
/// it shows, so a time zone change while it is open does not move them. There are no buttons: pulled away, it saves what
/// changed, and Date switched off takes the date away.
struct DuePickerSheet: View {
    @Environment(\.rules) private var rules
    @Environment(AppModel.self) private var model
    @State private var pick: DuePick
    @State private var hasDate = true
    private let opened: DuePick
    private let choosesZone: Bool
    private let offersAlarmOff: Bool
    private let onSave: (DuePick?) -> Void

    init(pick: DuePick, choosesZone: Bool, offersAlarmOff: Bool = false, onSave: @escaping (DuePick?) -> Void) {
        _pick = State(initialValue: pick)
        opened = pick
        self.choosesZone = choosesZone
        self.offersAlarmOff = offersAlarmOff
        self.onSave = onSave
    }

    var body: some View {
        NavigationStack {
            Form {
                SwitchToggle("taskPage.due.date", isOn: $hasDate)
                    .accessibilityIdentifier("duePicker.hasDate")
                if hasDate {
                    DayField("taskPage.due.date", day: $pick.day)
                        .datePickerStyle(.graphical)
                    SwitchToggle("taskPage.due.hasTime", isOn: Binding(get: { pick.time != nil }, set: setHasTime))
                        .accessibilityIdentifier("duePicker.hasTime")
                    if let time = pick.time {
                        TimeField("taskPage.due.time", time: Binding(get: { time }, set: { pick.time = $0 }), on: pick.day)
                            .childRow()
                        if choosesZone {
                            zoneRow
                            AlarmRows(alarm: $pick.alarm, offersOff: offersAlarmOff)
                        }
                    }
                }
            }
            .toolbar(.hidden, for: .navigationBar)
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        // Only what changed: looking at the date of an undated task does not give it one.
        .onDisappear {
            if !hasDate { onSave(nil) } else if pick != opened { onSave(pick) }
        }
    }

    private var zoneRow: some View {
        NavigationLink {
            TimeZonePicker(selected: pick.zone) { pick.zone = $0 }
        } label: {
            LabeledContent("taskPage.timeZone") {
                Text(verbatim: TimeZonePicker.title(of: pick.zone, at: model.clock.now))
            }
        }
        .childRow()
        .accessibilityIdentifier("duePicker.timeZone")
    }

    private func setHasTime(_ isOn: Bool) {
        pick.time = isOn ? rules.editing.defaultTime : nil
        if !isOn { pick.alarm = nil }
    }
}
