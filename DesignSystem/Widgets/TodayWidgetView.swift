import SwiftUI

/// The Today widget body: pool and timeline in the app's arrangement
/// (`layouts/today-*.layout.json`), built from the same row and timeline components. Read-only.
struct TodayWidgetView: View {
    @Environment(\.tokens) private var tokens
    let plan: DayPlan
    let settings: AppSettings
    let layout: ScreenLayout
    let context: DayContext
    let maxTimelineHours: Int

    var body: some View {
        VStack(alignment: .leading, spacing: tokens.space(.chipGap)) {
            ScreenLayoutView(layout: layout) { id in
                switch id {
                case "pool": WidgetPoolBlock(plan: plan, visibleCount: settings.poolUsesVisibleCount ? settings.pool.visibleCount : nil)
                case "timeline": WidgetTimelineBlock(plan: plan, settings: settings, context: context, maxHours: maxTimelineHours)
                default: EmptyView()
                }
            }
        }
        .padding(tokens.space(.widgetPadding))
    }
}

/// Pool rows on plates, as in the app. Above the timeline: `visibleCount` rows and a counter of the rest.
/// Beside it (`visibleCount` nil): rows down to the bottom of the widget, the last one cut, no counter.
struct WidgetPoolBlock: View {
    @Environment(\.tokens) private var tokens
    let plan: DayPlan
    let visibleCount: Int?

    var body: some View {
        VStack(alignment: .leading, spacing: tokens.space(.chipGap)) {
            ForEach(visibleCount.map { Array(plan.pool.prefix($0)) } ?? plan.pool) { item in
                TaskRowView(item: item, today: plan.today, titleFont: tokens.font(.widgetTitle), showsDetails: false,
                            isCompact: true)
                    .taskPlate(isDone: item.isDone)
            }
            if let visibleCount, plan.pool.count > visibleCount {
                Text(L10n.format("pool.more", plan.pool.count - visibleCount))
                    .font(tokens.font(.widgetCaption))
                    .foregroundStyle(tokens.color(.secondaryText))
            } else if plan.pool.isEmpty {
                Text("pool.empty").font(tokens.font(.widgetCaption)).foregroundStyle(tokens.color(.secondaryText))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: visibleCount == nil ? .infinity : nil, alignment: .topLeading)
        .clipped()
        .frame(idealWidth: tokens.size(.poolWidth))
    }
}

/// The timeline scaled to the space the widget has.
struct WidgetTimelineBlock: View {
    @Environment(\.tokens) private var tokens
    let plan: DayPlan
    let settings: AppSettings
    let context: DayContext
    let maxHours: Int

    var body: some View {
        VStack(alignment: .leading, spacing: tokens.space(.chipGap)) {
            if !plan.allDayEvents.isEmpty {
                AllDayStrip(events: plan.allDayEvents, font: tokens.font(.widgetCaption), onTap: nil)
            }
            scaledTimeline
        }
    }

    private var scaledTimeline: some View {
        GeometryReader { geometry in
            let timeline = settings.timeline
            switch settings.timelineMode {
            case .aroundNow:
                let before = min(timeline.hoursBefore, 1)
                let window = TimelineWindow.rolling(now: plan.now, hoursBefore: before,
                                                    hoursAfter: max(min(timeline.hoursAfter, maxHours - before), 1), calendar: context.calendar)
                let hourHeight = geometry.size.height / CGFloat(window.duration / 3600)
                DayTimelineView(slots: plan.timeline, window: window, now: plan.now, hourHeight: hourHeight,
                                style: style(hourHeight: hourHeight), taskContent: { item, _ in row(item, hourHeight: hourHeight) })
            case .wholeDay:
                let window = TimelineWindow.fixed(start: timeline.wholeDay.start, end: timeline.wholeDay.end, context: context)
                let hourHeight = geometry.size.height / CGFloat(max(window.duration, 3600) / 3600)
                DayTimelineView(slots: plan.timeline, window: window, now: plan.now, hourHeight: hourHeight,
                                style: style(hourHeight: hourHeight), taskContent: { item, _ in row(item, hourHeight: hourHeight) })
            case .halves:
                let hourHeight = geometry.size.height / CGFloat(max(timeline.halvesLongestHours, 1))
                HalvesTimeline(plan: plan, settings: timeline, context: context, height: geometry.size.height,
                               style: style(hourHeight: hourHeight), taskContent: { item, _ in row(item, hourHeight: hourHeight) })
            }
        }
    }

    /// Blocks are at least half an hour high in the current scale, so more hours = smaller blocks
    /// and nothing overlaps.
    private func style(hourHeight: CGFloat) -> TimelineStyle {
        // Half an hour in the current scale, but never less than one line of text.
        let minimum = max(hourHeight / 2, tokens.uiFont(.widgetCaption).lineHeight + tokens.space(.timelineItemGap) * 2)
        var style = TimelineStyle(eventFont: tokens.font(.widgetCaption), taskFont: tokens.font(.widgetCaption),
                                  minimumItemHeight: minimum, minimumTaskHeight: minimum)
        style.compactPlates = true
        return style
    }

    private func row(_ item: DayItem, hourHeight: CGFloat) -> some View {
        TaskRowView(item: item, today: plan.today, titleFont: tokens.font(.widgetCaption), showsDetails: false, titleLineLimit: 1)
    }
}
