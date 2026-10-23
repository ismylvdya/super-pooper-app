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
    func placeholder(in context: Context) -> TodayEntry { TodayEntry(date: Date(), source: WidgetDataSource.load()) }

    func getSnapshot(in context: Context, completion: @escaping (TodayEntry) -> Void) {
        completion(placeholder(in: context))
    }

    /// One entry per few minutes so "now" and the chains move; the app reloads it on every change.
    func getTimeline(in context: Context, completion: @escaping (Timeline<TodayEntry>) -> Void) {
        let source = WidgetDataSource.load()
        let step = Double(source?.config.rules.widgets.refreshMinutes ?? 15) * 60
        let count = source?.config.rules.widgets.entryCount ?? 24
        let now = Date()
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
    }
}
