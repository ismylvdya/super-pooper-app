import SwiftUI

/// The system date picker for a task date: the calendar, an optional time and, where the item keeps a zone, the Time
/// zone (None unless one is chosen; it only means something with a time) and whether it rings as an alarm. It keeps the wall-clock day and time it
/// shows, so a time zone change while it is open does not move them. Remove date clears the date; Done saves the pick.
struct DuePickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.rules) private var rules
    @Environment(\.tokens) private var tokens
    @State private var pick: DuePick
    private let choosesZone: Bool
    private let offersAlarmOff: Bool
    private let onSave: (DuePick?) -> Void

    init(pick: DuePick, choosesZone: Bool, offersAlarmOff: Bool = false, onSave: @escaping (DuePick?) -> Void) {
        _pick = State(initialValue: pick)
        self.choosesZone = choosesZone
        self.offersAlarmOff = offersAlarmOff
        self.onSave = onSave
    }

    var body: some View {
        NavigationStack {
            Form {
                DayField("taskPage.due.date", day: $pick.day)
                    .datePickerStyle(.graphical)
                Toggle("taskPage.due.hasTime", isOn: Binding(get: { pick.time != nil },
                                                             set: { pick.time = $0 ? rules.editing.defaultTime : nil }))
                    .accessibilityIdentifier("duePicker.hasTime")
                if let time = pick.time {
                    TimeField("taskPage.due.time", time: Binding(get: { time }, set: { pick.time = $0 }), on: pick.day)
                }
                if choosesZone {
                    zoneRow
                    if pick.time != nil { AlarmRows(alarm: $pick.alarm, offersOff: offersAlarmOff) }
                }
            }
            .navigationTitle(Text("duePicker.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("common.cancel") { dismiss() } }
                ToolbarItem(placement: .destructiveAction) {
                    Button("duePicker.clear") { save(nil) }
                        .accessibilityIdentifier("duePicker.clear")
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("common.done") { save(pick) }
                        .font(tokens.font(.emptyAction))
                        .accessibilityIdentifier("duePicker.done")
                }
            }
        }
        .presentationDetents([.large])
    }

    private var zoneRow: some View {
        NavigationLink {
            TimeZonePicker(selected: pick.zone) { pick.zone = $0 }
        } label: {
            LabeledContent("taskPage.timeZone") {
                Text(verbatim: TimeZonePicker.title(of: pick.zone))
            }
        }
        .disabled(pick.time == nil)
        .accessibilityIdentifier("duePicker.timeZone")
    }

    private func save(_ pick: DuePick?) {
        onSave(pick)
        dismiss()
    }
}
