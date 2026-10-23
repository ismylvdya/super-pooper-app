import SwiftUI

/// The timeline block. Stacked arrangement: one rolling column or two fixed halves; side by side:
/// hours around now or the whole day fitted into one column. Tapping an event opens Calendar.
struct TimelineBlock: View {
    @Environment(AppModel.self) private var model
    @Environment(\.tokens) private var tokens
    @Environment(\.openURL) private var openURL
    let plan: DayPlan
    let handler: TaskActionHandler
    /// Space under the block that belongs to the home indicator (the timeline scrolls under it).
    let bottomInset: CGFloat

    var body: some View {
        let settings = model.settings.timeline
        switch model.settings.timelineMode {
        case .aroundNow:
            ScrollView {
                DayTimelineView(slots: plan.timeline, window: rollingWindow(settings), now: plan.now,
                                hourHeight: tokens.size(.hourHeight), style: style, taskContent: taskRow)
                    .padding(.vertical, tokens.space(.groupGap) / 2)
            }
            .contentMargins(.bottom, bottomInset, for: .scrollContent)
            .scrollIndicators(.hidden)
            .edgeFades(bottomExtension: bottomInset)
        case .wholeDay:
            GeometryReader { geometry in
                let window = TimelineWindow.fixed(start: settings.wholeDay.start, end: settings.wholeDay.end,
                                                  context: model.context(at: plan.now))
                let height = geometry.size.height - bottomInset - tokens.space(.groupGap)
                ScrollView {
                    DayTimelineView(slots: plan.timeline, window: window, now: plan.now,
                                    hourHeight: max(height, 1) / CGFloat(max(window.duration, 3600) / 3600),
                                    style: style, taskContent: taskRow)
                        .padding(.vertical, tokens.space(.groupGap) / 2)
                }
                .contentMargins(.bottom, bottomInset, for: .scrollContent)
                .scrollBounceBehavior(.always)
                .scrollIndicators(.hidden)
                .edgeFades(bottomExtension: bottomInset)
            }
        case .halves:
            GeometryReader { geometry in
                ScrollView {
                    HalvesTimeline(plan: plan, settings: settings, context: model.context(at: plan.now),
                                   height: geometry.size.height - bottomInset - tokens.space(.groupGap),
                                   style: style, taskContent: taskRow)
                        .padding(.vertical, tokens.space(.groupGap) / 2)
                }
                .contentMargins(.bottom, bottomInset, for: .scrollContent)
                .scrollBounceBehavior(.always)
                .scrollIndicators(.hidden)
            }
        }
    }

    private var style: TimelineStyle {
        var style = TimelineStyle.make(model.settings.timeline, tokens: tokens)
        let prefix = model.config.rules.eventLinks.calendarAppURL
        style.onEventTap = { event in
            if let url = URL(string: "\(prefix)\(Int(event.start.timeIntervalSinceReferenceDate))") { openURL(url) }
        }
        return style
    }

    private func rollingWindow(_ settings: AppSettings.Timeline) -> TimelineWindow {
        TimelineWindow.rolling(now: plan.now, hoursBefore: settings.hoursBefore,
                               hoursAfter: min(settings.hoursAfter, model.config.rules.timeline.maxHoursAfter),
                               calendar: model.calendar)
    }

    /// The same row as in the pool (compact: one title line, chips dissolving on the right).
    private func taskRow(_ item: DayItem, _ slot: TimelineSlot) -> some View {
        PoolRowContent(item: item, today: plan.today, titleFont: .system(size: model.settings.timeline.taskFontSize),
                       handler: handler)
    }
}
