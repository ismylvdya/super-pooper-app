import SwiftUI
import WidgetKit

/// Large widget: pool and timeline from the app's snapshot. Tap opens the app.
struct TodayWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "SuperPooperToday", provider: TodayProvider()) { entry in
            TodayWidgetEntryView(entry: entry)
        }
        .configurationDisplayName("widget.today.name")
        .description("widget.today.description")
        .supportedFamilies([.systemLarge])
        .contentMarginsDisabled()
    }
}

struct TodayEntry: TimelineEntry {
    let date: Date
    let source: WidgetDataSource?
}

struct TodayProvider: TimelineProvider {
    private let clock: Clock = SystemClock()

    func placeholder(in context: Context) -> TodayEntry { TodayEntry(date: clock.now, source: WidgetDataSource.load()) }

    func getSnapshot(in context: Context, completion: @escaping (TodayEntry) -> Void) {
        completion(placeholder(in: context))
    }

    /// One entry per few minutes so "now" and the chains move; the app reloads it on every change.
    func getTimeline(in context: Context, completion: @escaping (Timeline<TodayEntry>) -> Void) {
        let source = WidgetDataSource.load()
        let rules = (source?.config.rules ?? BundledConfig.rules).widgets
        let step = Double(rules.refreshMinutes) * 60
        let count = rules.entryCount
        let now = clock.now
        let entries = (0..<count).map { TodayEntry(date: now.addingTimeInterval(Double($0) * step), source: source) }
        completion(Timeline(entries: entries, policy: .atEnd))
    }
}

struct TodayWidgetEntryView: View {
    @Environment(\.tokens) private var tokens
    let entry: TodayEntry

    var body: some View {
        Group {
            if let source = entry.source, source.snapshot != nil {
                TodayWidgetView(plan: source.plan(at: entry.date), settings: source.settings, layout: source.config.todayLayout(for: source.settings.today.arrangement),
                                context: source.context(at: entry.date), maxTimelineHours: source.config.rules.widgets.timelineHours)
            } else {
                Text("widget.empty").font(tokens.font(.widgetCaption)).foregroundStyle(tokens.color(.secondaryText)).padding()
            }
        }
        .containerBackground(tokens.color(.screenBackground), for: .widget)
        .widgetURL(DeepLink.today)
        .environment(\.tokens, entry.source.map { $0.config.tokens.applying($0.settings, limits: $0.config.rules.limits) } ?? tokens)
        .environment(\.timelineBell, (entry.source?.settings ?? BundledConfig.settings).timeline.bellStyle)
        .environment(\.calendar, entry.source?.calendar ?? AppCalendar.make())
    }
}
