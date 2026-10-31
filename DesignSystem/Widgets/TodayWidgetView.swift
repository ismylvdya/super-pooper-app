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
        VStack(alignment: .leading, spacing: tokens.space(.widgetGap)) {
            ScreenLayoutView(layout: layout) { id in
                switch id {
                case .pool: WidgetPoolBlock(plan: plan, visibleCount: settings.poolUsesVisibleCount ? settings.pool.visibleCount : nil)
                case .timeline: WidgetTimelineBlock(plan: plan, settings: settings, context: context, maxHours: maxTimelineHours)
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
        VStack(alignment: .leading, spacing: tokens.space(.widgetGap)) {
            // The same plates as Today, without chips; habits of one routine share a plate.
            ForEach(PoolSegments.make(visibleCount.map { Array(plan.pool.prefix($0)) } ?? plan.pool)) { segment in
                VStack(alignment: .leading, spacing: tokens.space(.widgetGap)) {
                    ForEach(segment.items) { item in
                        TaskRowView(item: item, today: plan.today, titleFont: tokens.font(.widgetTitle), showsDetails: false,
                                    isCompact: true, titleLineHeight: tokens.uiFont(.widgetTitle).lineHeight)
                    }
                }
                .taskPlate(isDone: segment.items.allSatisfy(\.isDone))
                // A subtask sits under its parent, shifted right, as in the app's pool.
                .padding(.leading, CGFloat(segment.items.first?.depth ?? 0) * tokens.space(.subtaskIndent))
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
        // The pool starts at its first row; only the cut bottom fades (empty space under it stays empty).
        .fadingEdges(bottom: visibleCount == nil)
        .frame(idealWidth: tokens.size(.poolWidth))
    }
}

/// The timeline scaled to the space the widget has.
struct WidgetTimelineBlock: View {
    @Environment(\.tokens) private var tokens
    @Environment(\.rules) private var rules
    let plan: DayPlan
    let settings: AppSettings
    let context: DayContext
    let maxHours: Int

    var body: some View {
        VStack(alignment: .leading, spacing: tokens.space(.widgetGap)) {
            if !plan.allDayEvents.isEmpty {
                AllDayStrip(events: plan.allDayEvents, font: tokens.font(.widgetCaption), lineHeight: tokens.size(.widgetAllDayLine), onTap: nil)
            }
            // The widget shows a cut of the day: both ends fade.
            scaledTimeline.fadingEdges(top: true, bottom: true)
        }
    }

    private var scaledTimeline: some View {
        GeometryReader { geometry in
            let limits = TimelineSpan.Limits(hoursBefore: rules.widgets.maxHoursBefore, hours: maxHours)
            let windows = TimelineWindow.windows(settings.timelineSpan(limits: limits), around: plan.now, context: context)
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
        let minimum = max(minutes, tokens.uiFont(.widgetCaption).lineHeight + tokens.space(.compactPlateVertical) * 2)
        let line = tokens.uiFont(.widgetCaption).lineHeight
        var style = TimelineStyle(eventFont: tokens.font(.widgetCaption), taskFont: tokens.font(.widgetCaption),
                                  eventLineHeight: line, taskLineHeight: line,
                                  minimumItemHeight: minimum, minimumTaskHeight: minimum)
        style.compactPlates = true
        return style
    }

    /// As on the app's timeline: what is finished has left it, the rest is shown plainly (a twice-a-day habit after its
    /// first Done too).
    private func row(_ item: DayItem) -> some View {
        TaskRowView(item: item, today: plan.today, titleFont: tokens.font(.widgetCaption), showsDetails: false, titleLineLimit: 1,
                    titleLineHeight: tokens.uiFont(.widgetCaption).lineHeight, showsDoneState: false)
    }
}
