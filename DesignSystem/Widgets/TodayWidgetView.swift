import SwiftUI

/// The Today widget body: pool and timeline in the app's arrangement
/// (`layouts/today-*.layout.json`), built from the same row and timeline components. Read-only. The system puts its
/// margins around it.
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
    }
}

extension TodayWidgetView {
    /// The widget's day at `date` from what the app left in the App Group.
    init(source: WidgetDataSource, at date: Date) {
        self.init(plan: source.plan(at: date), settings: source.settings, arrangement: source.arrangement, layout: source.widgetLayout,
                  context: source.context(at: date), maxTimelineHours: source.config.rules.widgets.timelineHours)
    }
}
