import SwiftUI

/// The date sheet: three switches, each opening the next. Date with its calendar, Time with its time and, where the item
/// keeps a zone, the Time zone (None unless one is chosen), then Alarm with its sound. It keeps the wall-clock day and time
/// it shows, so a time zone change while it is open does not move them. There are no buttons: pulled away, it saves what
/// changed, and Date switched off takes the date away.
struct DuePickerSheet: View {
    @Environment(\.rules) private var rules
    @Environment(\.tokens) private var tokens
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
                Toggle("taskPage.due.date", isOn: $hasDate)
                    .accessibilityIdentifier("duePicker.hasDate")
                if hasDate {
                    calendar
                    Toggle("taskPage.due.hasTime", isOn: Binding(get: { pick.time != nil }, set: setHasTime))
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

    /// The system's calendar needs a width of its own, wider than a row under a switch: it is laid out wider and drawn smaller.
    private var calendar: some View {
        let scale = tokens.ratio(.duePickerCalendar)
        return ScaledToWidth(scale: scale) {
            DayField("taskPage.due.date", day: $pick.day)
                .datePickerStyle(.graphical)
                .labelsHidden()
                .scaleEffect(scale, anchor: .topLeading)
        }
        .childRow()
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

/// A view laid out `1 / scale` as wide as the width offered and taking `scale` of its height: with the view's own
/// `scaleEffect` from its top leading corner, it fills that width.
private struct ScaledToWidth: Layout {
    let scale: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.replacingUnspecifiedDimensions().width
        let height = subviews.first?.sizeThatFits(ProposedViewSize(width: width / scale, height: nil)).height ?? 0
        return CGSize(width: width, height: height * scale)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        subviews.first?.place(at: bounds.origin, anchor: .topLeading, proposal: ProposedViewSize(width: bounds.width / scale, height: nil))
    }
}
