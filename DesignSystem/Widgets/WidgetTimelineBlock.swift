import SwiftUI

/// The timeline scaled to the space the widget has.
struct WidgetTimelineBlock: View {
    @Environment(\.tokens) private var tokens
    @Environment(\.rules) private var rules
    let plan: DayPlan
    let settings: AppSettings
    let arrangement: AppSettings.TodayArrangement
    let context: DayContext
    let maxHours: Int

    var body: some View {
        VStack(alignment: .leading, spacing: tokens.space(.widgetGap)) {
            if !plan.allDayEvents.isEmpty {
                AllDayStrip(events: plan.allDayEvents, font: fonts.allDay, lineHeight: fonts.allDayLineHeight, onTap: nil)
            }
            // The widget shows a cut of the day: both ends fade.
            scaledTimeline.fadingEdges(top: true, bottom: true)
        }
    }

    private var fonts: TimelineFonts { .widget(tokens: tokens) }

    private var scaledTimeline: some View {
        GeometryReader { geometry in
            let limits = TimelineSpan.Limits(hoursBefore: rules.widgets.maxHoursBefore, hours: maxHours)
            let windows = TimelineWindow.windows(settings.timelineSpan(in: arrangement, limits: limits), around: plan.now, context: context)
            if windows.count > 1 {
                let hourHeight = geometry.size.height / CGFloat(max(windows.map(\.hours).max() ?? 1, 1))
                HalvesTimeline(plan: plan, windows: windows, settings: settings.timeline, height: geometry.size.height,
                               style: style(hourHeight: hourHeight), taskContent: { item, _ in row(item) })
            } else if let window = windows.first {
                let hourHeight = CGFloat(window.hourHeight(fitting: Double(geometry.size.height)))
                DayTimelineView(slots: plan.timeline, window: window, now: plan.now, hourHeight: hourHeight,
                                style: style(hourHeight: hourHeight), taskContent: { item, _ in row(item) })
            }
        }
    }

    /// Blocks are at least `widgets.minimumBlockMinutes` high in the current scale, so more hours = smaller blocks
    /// and nothing overlaps.
    private func style(hourHeight: CGFloat) -> TimelineStyle {
        // That many minutes in the current scale, but never less than one line of text.
        let minutes = hourHeight * CGFloat(rules.widgets.minimumBlockMinutes) / CGFloat(TimelineWindow.hour / 60)
        let minimum = max(minutes, fonts.taskLineHeight + tokens.space(.compactPlateVertical) * 2)
        var style = TimelineStyle(fonts: fonts, minimumItemHeight: minimum, minimumTaskHeight: minimum)
        style.compactPlates = true
        return style
    }

    /// As on the app's timeline: what is finished has left it, the rest is shown plainly (a twice-a-day habit after its
    /// first Done too).
    private func row(_ item: DayItem) -> some View {
        TaskRowView(item: item, titleFont: fonts.task, showsDetails: false, titleLineLimit: 1,
                    titleLineHeight: fonts.taskLineHeight, showsDoneState: false)
    }
}
