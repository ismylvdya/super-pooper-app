import SwiftUI

/// How faded done tasks and past events are, with a live preview of a done task and a past event.
struct AppearanceSettingsSection: View {
    @Environment(AppModel.self) private var model
    @Environment(\.tokens) private var tokens

    var body: some View {
        let opacity = model.settings.appearance.pastOpacity
        let limits = model.config.rules.limits.pastOpacity
        PlateSection(header: "settings.appearance", info: "info.settings.pastOpacity") {
            PlateRow(icon: .opacity, title: "settings.pastOpacity") {
                Text(opacity.formatted(.percent.precision(.fractionLength(0)))).monospacedDigit().foregroundStyle(tokens.color(.secondaryText))
            }
            Slider(value: Binding(get: { opacity },
                                  set: { value in model.updateSettings { $0.appearance.pastOpacity = limits.snapped(value) } }),
                   in: limits.closed)
                .accessibilityIdentifier("settings.pastOpacity")
            preview
        }
    }

    /// A sample done task and a sample past event, drawn exactly as on Today.
    private var preview: some View {
        let now = model.clock.now
        let task = TaskNote(name: L10n.string("settings.pastOpacity.sampleTask"), relativePath: "", status: .done)
        let item = DayItem(task: task, state: .marked(.done), blockers: [], problems: [])
        let event = CalendarEvent(eventIdentifier: "sample", title: L10n.string("settings.pastOpacity.sampleEvent"),
                                  start: now.addingTimeInterval(-7200), end: now.addingTimeInterval(-3600), isAllDay: false,
                                  calendarID: "", calendarTitle: "", colorHex: tokens.color(.task).hexValue)
        let slot = TimelineSlot(content: .event(event), start: event.start, end: event.end, isPast: true)
        return VStack(alignment: .leading, spacing: tokens.space(.poolRowGap)) {
            TaskRowView(item: item, today: model.context().today, isCompact: true).taskPlate(isDone: true)
            TimelineEventBlock(event: event, slot: slot, font: tokens.font(.rowTitle), lineHeight: tokens.uiFont(.rowTitle).lineHeight).fixedSize(horizontal: false, vertical: true)
        }
        .settingsPreviewFrame()
        .accessibilityHidden(true)
    }
}
