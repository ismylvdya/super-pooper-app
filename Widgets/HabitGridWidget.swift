import SwiftUI
import WidgetKit

/// Small/medium widget with the day grid of one recurring task (chosen in the widget settings).
struct HabitGridWidget: Widget {
    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: "SuperPooperHabitGrid", intent: SelectHabitIntent.self, provider: HabitGridProvider()) { entry in
            HabitGridEntryView(entry: entry)
        }
        .configurationDisplayName("widget.habit.name")
        .description("widget.habit.description")
        .supportedFamilies([.systemSmall, .systemMedium])
        .contentMarginsDisabled()
    }
}

struct HabitGridEntry: TimelineEntry {
    let date: Date
    let habitName: String?
    let source: WidgetDataSource?
}

struct HabitGridProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> HabitGridEntry {
        HabitGridEntry(date: Date(), habitName: nil, source: WidgetDataSource.load())
    }

    func snapshot(for configuration: SelectHabitIntent, in context: Context) async -> HabitGridEntry {
        HabitGridEntry(date: Date(), habitName: configuration.habit?.id, source: WidgetDataSource.load())
    }

    /// The grid only changes when the app writes a new snapshot (it reloads widgets) or the day ends.
    func timeline(for configuration: SelectHabitIntent, in context: Context) async -> Timeline<HabitGridEntry> {
        let entry = await snapshot(for: configuration, in: context)
        let nextDay = Calendar.current.startOfDay(for: Date()).addingTimeInterval(26 * 3600)
        return Timeline(entries: [entry], policy: .after(nextDay))
    }
}

struct HabitGridEntryView: View {
    @Environment(\.tokens) private var tokens
    @Environment(\.widgetFamily) private var family
    let entry: HabitGridEntry

    var body: some View {
        Group {
            if let source = entry.source, let habit = source.habit(named: entry.habitName) {
                let rules = source.config.rules.widgets
                HabitGridView(title: habit.name,
                              grid: HabitGrid(task: habit, weekCount: family == .systemSmall ? rules.habitGridWeeksSmall : rules.habitGridWeeksMedium,
                                              today: source.context(at: entry.date).today, calendar: source.calendar))
            } else {
                Text("widget.habit.empty").font(tokens.font(.widgetCaption)).foregroundStyle(tokens.color(.secondaryText)).padding()
            }
        }
        .containerBackground(tokens.color(.plateBackground), for: .widget)
        .widgetURL(entry.habitName.flatMap(DeepLink.task) ?? URL(string: "\(DeepLink.scheme)://today"))
    }
}
