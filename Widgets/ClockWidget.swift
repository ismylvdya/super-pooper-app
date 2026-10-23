import SwiftUI
import WidgetKit

/// Lock Screen line: the user's prefix and the time in the chosen zone (Moscow by default).
struct ClockWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "SuperPooperClock", provider: ClockProvider()) { entry in
            Text(verbatim: entry.text)
                .containerBackground(.clear, for: .widget)
                .widgetURL(DeepLink.clock)
        }
        .configurationDisplayName("widget.clock.name")
        .description("widget.clock.description")
        .supportedFamilies([.accessoryInline])
    }
}

struct ClockEntry: TimelineEntry {
    let date: Date
    let text: String
}

/// One entry per minute for the next hour; the line is computed from the stored settings.
struct ClockProvider: TimelineProvider {
    func placeholder(in context: Context) -> ClockEntry { entry(at: Date()) }

    func getSnapshot(in context: Context, completion: @escaping (ClockEntry) -> Void) {
        completion(entry(at: Date()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<ClockEntry>) -> Void) {
        let now = Date()
        let start = now.addingTimeInterval(-now.timeIntervalSince1970.truncatingRemainder(dividingBy: 60))
        let entries = (0..<60).map { entry(at: start.addingTimeInterval(Double($0) * 60)) }
        completion(Timeline(entries: entries, policy: .atEnd))
    }

    private func entry(at date: Date) -> ClockEntry {
        let settings = WidgetDataSource.load()?.settings.clock
        let zone = settings.flatMap { TimeZone(identifier: $0.timeZone) } ?? .current
        return ClockEntry(date: date, text: ClockLine.text(prefix: settings?.prefix ?? "", date: date, timeZone: zone))
    }
}
