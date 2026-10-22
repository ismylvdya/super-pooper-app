import SwiftUI

/// Two fixed columns (e.g. 06:00–14:00 and 14:00–22:00) scaled to fit the available height.
struct HalvesTimeline<TaskContent: View>: View {
    @Environment(\.tokens) private var tokens
    let plan: DayPlan
    let settings: AppSettings.Timeline
    let context: DayContext
    let height: CGFloat
    @ViewBuilder let taskContent: (DayItem, TimelineSlot) -> TaskContent

    var body: some View {
        let windows = [
            TimelineWindow.fixed(start: settings.firstHalf.start, end: settings.firstHalf.end, context: context),
            TimelineWindow.fixed(start: settings.secondHalf.start, end: settings.secondHalf.end, context: context),
        ]
        let longest = windows.map(\.duration).max() ?? 3600
        let hourHeight = max(height, 1) / CGFloat(longest / 3600)
        HStack(alignment: .top, spacing: tokens.space(.blockGap)) {
            ForEach(windows, id: \.self) { window in
                DayTimelineView(slots: plan.timeline, window: window, now: plan.now, hourHeight: hourHeight,
                                style: TimelineStyle.make(settings, tokens: tokens), taskContent: taskContent)
            }
        }
    }
}

extension TimelineStyle {
    static func make(_ settings: AppSettings.Timeline, tokens: DesignTokens) -> TimelineStyle {
        TimelineStyle(eventFont: .system(size: settings.eventFontSize),
                      taskFont: .system(size: settings.taskFontSize),
                      minimumItemHeight: max(UIFont.systemFont(ofSize: settings.taskFontSize).lineHeight,
                                             tokens.size(.checkbox) + 6) + tokens.space(.timelineItemPadding))
    }
}
