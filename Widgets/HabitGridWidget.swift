import SwiftUI
import WidgetKit

/// Small widget of one habit (chosen in the widget settings): today's button and the last weeks.
/// Tapping outside the button opens the habit's page.
struct HabitGridWidget: Widget {
    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: "SuperPooperHabitGrid", intent: SelectHabitIntent.self, provider: HabitGridProvider()) { entry in
            HabitGridEntryView(entry: entry)
        }
        .configurationDisplayName("widget.habit.name")
        .description("widget.habit.description")
        .supportedFamilies([.systemSmall])
        .contentMarginsDisabled()
    }
}

struct HabitGridEntry: TimelineEntry {
    let date: Date
    let habitName: String?
    let source: WidgetDataSource?
    var options = HabitWidgetOptions()
}

struct HabitGridProvider: AppIntentTimelineProvider {
    private let clock: Clock = SystemClock()

    func placeholder(in context: Context) -> HabitGridEntry {
        HabitGridEntry(date: clock.now, habitName: nil, source: WidgetDataSource.load())
    }

    func snapshot(for configuration: SelectHabitIntent, in context: Context) async -> HabitGridEntry {
        HabitGridEntry(date: clock.now, habitName: configuration.habit?.id, source: WidgetDataSource.load(),
                       options: HabitWidgetOptions(titleSize: configuration.titleSize.points, wrapTitle: configuration.wrapTitle,
                                                   breakWords: configuration.breakWords, weeks: configuration.weeks))
    }

    /// The grid only changes when the app writes a new snapshot (it reloads widgets) or the logical day ends.
    func timeline(for configuration: SelectHabitIntent, in context: Context) async -> Timeline<HabitGridEntry> {
        let entry = await snapshot(for: configuration, in: context)
        let retry = clock.now.addingTimeInterval(Double(BundledConfig.rules.widgets.refreshMinutes) * 60)
        let dayEnd = entry.source?.context(at: entry.date).dayEnd ?? retry
        return Timeline(entries: [entry], policy: .after(dayEnd))
    }
}

struct HabitGridEntryView: View {
    @Environment(\.tokens) private var tokens
    let entry: HabitGridEntry

    var body: some View {
        let habit = entry.source?.habit(named: entry.habitName)
        Group {
            if let source = entry.source, let habit {
                let today = source.context(at: entry.date).today
                HabitWidgetView(habit: habit,
                                grid: HabitGrid(task: habit, weekCount: entry.options.weeks, today: today, calendar: source.calendar),
                                today: today, options: entry.options)
            } else {
                Text("widget.habit.empty").font(tokens.font(.widgetCaption)).foregroundStyle(tokens.color(.secondaryText)).padding()
            }
        }
        .containerBackground(tokens.color(.plateBackground), for: .widget)
        .widgetURL(habit.flatMap { DeepLink.habit($0.name) } ?? DeepLink.habits)
        .environment(\.tokens, entry.source.map { $0.config.tokens.applying($0.settings, limits: $0.config.rules.limits) } ?? tokens)
        .environment(\.calendar, entry.source?.calendar ?? AppCalendar.make())
    }
}
