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
