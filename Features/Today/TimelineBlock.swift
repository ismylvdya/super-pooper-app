import SwiftUI

/// The timeline block: one wide rolling column or two fixed halves of the day (setting).
struct TimelineBlock: View {
    @Environment(AppModel.self) private var model
    @Environment(\.tokens) private var tokens
    let plan: DayPlan
    let handler: TaskActionHandler

    var body: some View {
        let settings = model.settings.timeline
        switch settings.layout {
        case .oneColumn:
            ScrollView {
                DayTimelineView(slots: plan.timeline, window: rollingWindow(settings), now: plan.now,
                                hourHeight: tokens.size(.hourHeight), style: TimelineStyle.make(settings, tokens: tokens),
                                taskContent: taskRow)
                    .padding(.vertical, tokens.space(.groupGap) / 2)
            }
            .scrollIndicators(.hidden)
            .edgeFades()
        case .twoColumns:
            GeometryReader { geometry in
                ScrollView {
                    HalvesTimeline(plan: plan, settings: settings, context: model.context(at: plan.now),
                                   height: geometry.size.height - tokens.space(.groupGap), taskContent: taskRow)
                        .padding(.vertical, tokens.space(.groupGap) / 2)
                }
                .scrollBounceBehavior(.always)
                .scrollIndicators(.hidden)
            }
        }
    }

    private func rollingWindow(_ settings: AppSettings.Timeline) -> TimelineWindow {
        TimelineWindow.rolling(now: plan.now, hoursBefore: settings.hoursBefore,
                               hoursAfter: min(settings.hoursAfter, model.config.rules.timeline.maxHoursAfter),
                               calendar: model.calendar)
    }

    private func taskRow(_ item: DayItem, _ slot: TimelineSlot) -> some View {
        TaskRowView(item: item, today: plan.today, titleFont: .system(size: model.settings.timeline.taskFontSize),
                    showsDetails: false,
                    onToggle: { handler.toggle(item.id) },
                    onOpen: { handler.run(ActionRegistryLookup.open, taskName: item.id) })
            .contextMenu {
                ActionMenuContent(menu: item.isHabit ? .habitContext : .taskContext, item: item) {
                    handler.handle($0, taskName: item.id)
                }
            }
    }
}

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
