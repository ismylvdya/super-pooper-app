import SwiftUI

/// The Today widget body: pool and timeline in the same layout as the app (`today.layout.json`),
/// built from the same row and timeline components. Read-only.
struct TodayWidgetView: View {
    @Environment(\.tokens) private var tokens
    let plan: DayPlan
    let settings: AppSettings
    let layout: ScreenLayout
    let calendar: Calendar
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
                case "pool": WidgetPoolBlock(plan: plan, visibleCount: settings.pool.visibleCount)
                case "timeline": WidgetTimelineBlock(plan: plan, settings: settings.timeline, calendar: calendar,
                                                     maxHours: maxTimelineHours)
                default: EmptyView()
                }
            }
        }
        .padding(tokens.space(.widgetPadding))
    }
}

/// The first N pool rows and a counter of the rest.
struct WidgetPoolBlock: View {
    @Environment(\.tokens) private var tokens
    let plan: DayPlan
    let visibleCount: Int

    var body: some View {
        VStack(alignment: .leading, spacing: tokens.space(.chipGap)) {
            ForEach(plan.pool.prefix(visibleCount)) { item in
                TaskRowView(item: item, today: plan.today, titleFont: tokens.font(.widgetTitle), showsDetails: false)
            }
            if plan.pool.count > visibleCount {
                Text(L10n.format("pool.more", plan.pool.count - visibleCount))
                    .font(tokens.font(.widgetCaption))
                    .foregroundStyle(tokens.color(.secondaryText))
            } else if plan.pool.isEmpty {
                Text("pool.empty").font(tokens.font(.widgetCaption)).foregroundStyle(tokens.color(.secondaryText))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(idealWidth: tokens.size(.poolWidth))
    }
}

/// The timeline scaled to the space the widget has.
struct WidgetTimelineBlock: View {
    @Environment(\.tokens) private var tokens
    let plan: DayPlan
    let settings: AppSettings.Timeline
    let calendar: Calendar
    let maxHours: Int

    var body: some View {
        GeometryReader { geometry in
            let style = TimelineStyle(eventFont: tokens.font(.widgetCaption), taskFont: tokens.font(.widgetCaption),
                                      minimumItemHeight: tokens.size(.checkbox))
            switch settings.layout {
            case .oneColumn:
                let before = min(settings.hoursBefore, 1)
                let window = TimelineWindow.rolling(now: plan.now, hoursBefore: before,
                                                    hoursAfter: max(min(settings.hoursAfter, maxHours - before), 1), calendar: calendar)
                DayTimelineView(slots: plan.timeline, window: window, now: plan.now,
                                hourHeight: geometry.size.height / CGFloat(window.duration / 3600), style: style, taskContent: row)
            case .twoColumns:
                HalvesTimeline(plan: plan, settings: settings,
                               context: DayContext(now: plan.now, calendar: calendar, boundary: .midnight, energyHour: .midnight),
                               height: geometry.size.height, taskContent: row)
            }
        }
    }

    private func row(_ item: DayItem, _ slot: TimelineSlot) -> some View {
        TaskRowView(item: item, today: plan.today, titleFont: tokens.font(.widgetCaption), showsDetails: false)
    }
}
