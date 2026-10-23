import SwiftUI

/// Settings of the habits side: whether new habits show in Today, the habit colors, and how the parts of
/// the day are split for sorting (read-only, from rules).
struct HabitSettingsScreen: View {
    @Environment(AppModel.self) private var model
    @Environment(\.rules) private var rules

    var body: some View {
        PageScaffold(title: L10n.string("settings.habits")) {
            PlateSection(header: "settings.habits.new", hint: "settings.habits.new.hint") {
                PlateRow(icon: .today, title: "habitPage.showInToday", info: "info.habitPage.showInToday") {
                    Toggle("habitPage.showInToday", isOn: Binding(
                        get: { model.settings.habits.showInTodayByDefault },
                        set: { value in model.updateSettings { $0.habits.showInTodayByDefault = value } }
                    ))
                    .labelsHidden()
                }
            }
            PlateSection(header: "settings.habits.colors", hint: "settings.habits.colors.hint") {
                ForEach([ColorToken.habit, .twice, .missed], id: \.self) { token in
                    PlateRow(icon: nil, title: LocalizedStringKey(String("color.") + token.rawValue)) { ColorField(token: token) }
                }
            }
            PlateSection(header: "settings.habits.partsOfDay", info: "info.settings.habits.partsOfDay") {
                PlateRow(icon: .timeOfDay, title: "habitPage.timeOfDay.morning") {
                    Text(L10n.format("settings.habits.until", rules.day.morningEnds.string)).foregroundStyle(.secondary)
                }
                PlateRow(icon: nil, title: "habitPage.timeOfDay.evening") {
                    Text(L10n.format("settings.habits.from", rules.day.eveningStarts.string)).foregroundStyle(.secondary)
                }
            }
        }
    }
}

/// How faded done tasks and past events are, with a live preview of a done task and a past event.
struct AppearanceSettingsSection: View {
    @Environment(AppModel.self) private var model
    @Environment(\.tokens) private var tokens

    var body: some View {
        let opacity = model.settings.appearance.pastOpacity
        PlateSection(header: "settings.appearance", info: "info.settings.pastOpacity") {
            PlateRow(icon: .opacity, title: "settings.pastOpacity") {
                Text(opacity.formatted(.percent.precision(.fractionLength(0)))).monospacedDigit().foregroundStyle(.secondary)
            }
            Slider(value: Binding(get: { opacity },
                                  set: { value in model.updateSettings { $0.appearance.pastOpacity = (value * 20).rounded() / 20 } }),
                   in: 0.05...1)
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
            TimelineEventBlock(event: event, slot: slot, font: tokens.font(.rowTitle)).fixedSize(horizontal: false, vertical: true)
        }
        .padding(tokens.space(.chipGap))
        .background(tokens.color(.screenBackground), in: RoundedRectangle(cornerRadius: tokens.radius(.timelineItem), style: .continuous))
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}
