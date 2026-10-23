import SwiftUI

/// The Today widget body: title above, then pool and timeline in the app's arrangement
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
            HStack {
                Text("today.title").font(tokens.font(.widgetTitle))
                Spacer()
                Text(plan.now.formatted(.dateTime.weekday(.abbreviated).day()))
                    .font(tokens.font(.widgetCaption))
                    .foregroundStyle(tokens.color(.secondaryText))
            }
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

/// Pool rows on plates, as in the app, and a counter of the rest. `visibleCount` nil = as many
/// rows as fit the full height (side-by-side arrangement).
struct WidgetPoolBlock: View {
    @Environment(\.tokens) private var tokens
    let plan: DayPlan
    let visibleCount: Int?

    var body: some View {
        GeometryReader { geometry in
            let fitting = Int((geometry.size.height - tokens.size(.poolCounter))
                / (tokens.size(.widgetRowHeight) + tokens.space(.chipGap)))
            let count = max(visibleCount ?? fitting, 1)
            VStack(alignment: .leading, spacing: tokens.space(.chipGap)) {
                ForEach(plan.pool.prefix(count)) { item in
                    TaskRowView(item: item, today: plan.today, titleFont: tokens.font(.widgetTitle), showsDetails: false,
                                isCompact: true, togglesWithIntent: true)
                        .taskPlate()
                }
                if plan.pool.count > count {
                    Text(L10n.format("pool.more", plan.pool.count - count))
                        .font(tokens.font(.widgetCaption))
                        .foregroundStyle(tokens.color(.secondaryText))
                } else if plan.pool.isEmpty {
                    Text("pool.empty").font(tokens.font(.widgetCaption)).foregroundStyle(tokens.color(.secondaryText))
                }
            }
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .frame(idealWidth: tokens.size(.poolWidth), idealHeight: visibleCount.map {
            CGFloat($0) * (tokens.size(.widgetRowHeight) + tokens.space(.chipGap)) + tokens.size(.poolCounter)
        })
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
        GeometryReader { geometry in
            let style = TimelineStyle(eventFont: tokens.font(.widgetCaption), taskFont: tokens.font(.widgetCaption),
                                      minimumItemHeight: tokens.size(.checkbox))
            let timeline = settings.timeline
            switch settings.timelineMode {
            case .aroundNow:
                let before = min(timeline.hoursBefore, 1)
                let window = TimelineWindow.rolling(now: plan.now, hoursBefore: before,
                                                    hoursAfter: max(min(timeline.hoursAfter, maxHours - before), 1), calendar: context.calendar)
                DayTimelineView(slots: plan.timeline, window: window, now: plan.now,
                                hourHeight: geometry.size.height / CGFloat(window.duration / 3600), style: style, taskContent: row)
            case .wholeDay:
                let window = TimelineWindow.fixed(start: timeline.wholeDay.start, end: timeline.wholeDay.end, context: context)
                DayTimelineView(slots: plan.timeline, window: window, now: plan.now,
                                hourHeight: geometry.size.height / CGFloat(max(window.duration, 3600) / 3600), style: style, taskContent: row)
            case .halves:
                HalvesTimeline(plan: plan, settings: timeline, context: context, height: geometry.size.height, style: style,
                               taskContent: row)
            }
        }
    }

    private func row(_ item: DayItem, _ slot: TimelineSlot) -> some View {
        TaskRowView(item: item, today: plan.today, titleFont: tokens.font(.widgetCaption), showsDetails: false, titleLineLimit: 2,
                    togglesWithIntent: true)
    }
}
