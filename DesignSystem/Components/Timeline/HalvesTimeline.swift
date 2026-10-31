import SwiftUI

/// Two fixed columns (e.g. 06:00–14:00 and 14:00–22:00, `TimelineWindow.windows`) scaled to fit the available height.
struct HalvesTimeline<TaskContent: View>: View {
    @Environment(\.tokens) private var tokens
    let plan: DayPlan
    let windows: [TimelineWindow]
    let settings: AppSettings.Timeline
    let height: CGFloat
    var style: TimelineStyle?
    @ViewBuilder let taskContent: (DayItem, TimelineSlot) -> TaskContent

    var body: some View {
        let hourHeight = max(height, 1) / CGFloat(windows.map(\.hours).max() ?? 1)
        HStack(alignment: .top, spacing: tokens.space(.blockGap)) {
            ForEach(windows, id: \.self) { window in
                DayTimelineView(slots: plan.timeline, window: window, now: plan.now, hourHeight: hourHeight,
                                style: style ?? TimelineStyle.make(settings, tokens: tokens), taskContent: taskContent)
            }
        }
    }
}

extension TimelineStyle {
    static func make(_ settings: AppSettings.Timeline, tokens: DesignTokens) -> TimelineStyle {
        let taskLine = tokens.uiFont(.timelineText, size: settings.taskFontSize).lineHeight
        let titleLine = taskLine + tokens.space(.timelineTitleExtra)
        return TimelineStyle(eventFont: tokens.font(.timelineEvent, size: settings.eventFontSize),
                             taskFont: tokens.font(.timelineText, size: settings.taskFontSize),
                             eventLineHeight: tokens.uiFont(.timelineEvent, size: settings.eventFontSize).lineHeight,
                             taskLineHeight: taskLine,
                             minimumItemHeight: titleLine + tokens.space(.timelineItemPadding),
                             // As high as the title row plus the plate padding: equal space above and below.
                             minimumTaskHeight: titleLine + tokens.space(.rowVertical))
    }
}
