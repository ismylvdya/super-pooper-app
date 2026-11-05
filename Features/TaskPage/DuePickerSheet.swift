import SwiftUI

/// The system date picker for a task date: the calendar, an optional time and, where the item keeps a zone, the Time
/// zone (None unless one is chosen; it only means something with a time) and whether it rings as an alarm. It keeps the wall-clock day and time it
/// shows, so a time zone change while it is open does not move them. Remove date clears the date; closing the sheet in any way saves what changed.
struct DuePickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.rules) private var rules
    @Environment(AppModel.self) private var model
    @State private var pick: DuePick
    @State private var isCleared = false
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
                ToolbarItem(placement: .cancellationAction) { SheetCloseButton().accessibilityIdentifier("duePicker.close") }
                ToolbarItem(placement: .destructiveAction) {
                    Button("duePicker.clear", action: clear)
                        .accessibilityIdentifier("duePicker.clear")
                }
            }
        }
        .presentationDetents([.large])
        // Only what changed: looking at the date of an undated task does not give it one.
        .onDisappear { if !isCleared, pick != opened { onSave(pick) } }
    }

    private var zoneRow: some View {
        NavigationLink {
            TimeZonePicker(selected: pick.zone) { pick.zone = $0 }
        } label: {
            LabeledContent("taskPage.timeZone") {
                Text(verbatim: TimeZonePicker.title(of: pick.zone, at: model.clock.now))
            }
        }
        .disabled(pick.time == nil)
        .accessibilityIdentifier("duePicker.timeZone")
    }

    private func clear() {
        isCleared = true
        onSave(nil)
        dismiss()
    }
}
