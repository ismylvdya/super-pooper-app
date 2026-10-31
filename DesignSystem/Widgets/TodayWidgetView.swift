import SwiftUI

/// The Today widget body: pool and timeline in the app's arrangement
/// (`layouts/today-*.layout.json`), built from the same row and timeline components. Read-only.
struct TodayWidgetView: View {
    @Environment(\.tokens) private var tokens
    let plan: DayPlan
    let settings: AppSettings
    /// The widget's own arrangement and its layout, not the app's.
    let arrangement: AppSettings.TodayArrangement
    let layout: ScreenLayout
    let context: DayContext
    let maxTimelineHours: Int

    var body: some View {
        VStack(alignment: .leading, spacing: tokens.space(.widgetGap)) {
            ScreenLayoutView(layout: layout) { id in
                switch id {
                case .pool:
                    WidgetPoolBlock(plan: plan, visibleCount: settings.poolUsesVisibleCount(in: arrangement) ? settings.pool.visibleCount : nil)
                case .timeline:
                    WidgetTimelineBlock(plan: plan, settings: settings, arrangement: arrangement, context: context, maxHours: maxTimelineHours)
                }
            }
        }
        .padding(tokens.space(.widgetPadding))
    }
}

extension TodayWidgetView {
    /// The widget's day at `date` from what the app left in the App Group.
    init(source: WidgetDataSource, at date: Date) {
        self.init(plan: source.plan(at: date), settings: source.settings, arrangement: source.arrangement, layout: source.widgetLayout,
                  context: source.context(at: date), maxTimelineHours: source.config.rules.widgets.timelineHours)
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
                PoolSegmentView(segment: segment) { item, plate in
                    TaskRowView(item: item, titleFont: tokens.font(.widgetTitle), showsDetails: false,
                                isCompact: true, titleLineHeight: tokens.uiFont(.widgetTitle).lineHeight)
                        .poolRowPlate(plate, isDone: item.isDone)
                        // A subtask sits under its parent, shifted right, as in the app's pool.
                        .padding(.leading, CGFloat(item.depth) * tokens.space(.subtaskIndent))
                }
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
