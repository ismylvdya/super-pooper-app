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
    private let clock: Clock = SystemClock()

    func placeholder(in context: Context) -> ClockEntry { entry(at: clock.now, settings: WidgetDataSource.load()?.settings.clock) }

    func getSnapshot(in context: Context, completion: @escaping (ClockEntry) -> Void) {
        completion(placeholder(in: context))
    }

    /// The stored settings are read once for the whole hour of entries.
    func getTimeline(in context: Context, completion: @escaping (Timeline<ClockEntry>) -> Void) {
        let settings = WidgetDataSource.load()?.settings.clock
        let now = clock.now
        let minute: TimeInterval = 60
        let start = now.addingTimeInterval(-now.timeIntervalSince1970.truncatingRemainder(dividingBy: minute))
        let entries = (0..<Int(3600 / minute)).map { entry(at: start.addingTimeInterval(Double($0) * minute), settings: settings) }
        completion(Timeline(entries: entries, policy: .atEnd))
    }

    private func entry(at date: Date, settings: AppSettings.Clock?) -> ClockEntry {
        let zone = settings.flatMap { TimeZone(identifier: $0.timeZone) } ?? .current
        return ClockEntry(date: date, text: ClockLine.text(prefix: settings?.prefix ?? "", date: date, timeZone: zone))
    }
}
