import SwiftUI

/// How faded done tasks and past events are, with a live preview of a done task and a past event.
struct AppearanceSettingsSection: View {
    @Environment(AppModel.self) private var model
    @Environment(\.tokens) private var tokens

    var body: some View {
        PlateSection(header: "settings.appearance", info: "info.settings.pastOpacity") {
            SettingSlider(icon: .opacity, title: "settings.pastOpacity", value: \.appearance.pastOpacity,
                        limits: model.config.rules.limits.pastOpacity, accessibilityID: "settings.pastOpacity")
            preview
        }
    }

    /// A sample done task and a sample past event, drawn exactly as on Today.
    private var preview: some View {
        let now = model.clock.now
        let item = DayItem(listed: TaskItem(id: .unsaved, name: L10n.string("settings.pastOpacity.sampleTask"), status: .done))
        // An hour-long event that ended an hour ago.
        let end = now.addingTimeInterval(-TimelineWindow.hour)
        let event = CalendarEvent(eventIdentifier: "sample", title: L10n.string("settings.pastOpacity.sampleEvent"),
                                  start: end.addingTimeInterval(-TimelineWindow.hour), end: end, isAllDay: false,
                                  calendarID: "", calendarTitle: "", colorHex: tokens.color(.task).hexValue)
        let slot = TimelineSlot(content: .event(event), start: event.start, end: event.end, isPast: true)
        return VStack(alignment: .leading, spacing: tokens.space(.poolRowGap)) {
            TaskRowView(item: item, isCompact: true).taskPlate(isDone: true)
            TimelineEventBlock(event: event, slot: slot, font: tokens.font(.timelineText), lineHeight: tokens.uiFont(.timelineText).lineHeight).fixedSize(horizontal: false, vertical: true)
        }
        .settingsPreviewFrame()
        .accessibilityHidden(true)
    }
}
