import SwiftUI

/// The timeline block. Stacked arrangement: one rolling column or two fixed halves; side by side:
/// hours around now or the whole day fitted into one column. Tapping an event opens Calendar.
struct TimelineBlock: View {
    @Environment(AppModel.self) private var model
    @Environment(\.tokens) private var tokens
    @Environment(\.openURL) private var openURL
    @State private var eventToDelete: CalendarEvent?
    let plan: DayPlan
    let handler: TaskActionHandler
    /// Space under the block that belongs to the home indicator (the timeline scrolls under it).
    let bottomInset: CGFloat

    @ViewBuilder private var content: some View {
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
            .refreshable { await model.sync(announce: true) }
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
                .refreshable { await model.sync(announce: true) }
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
                .refreshable { await model.sync(announce: true) }
            }
        }
    }

    /// The block with the dialog for the one timeline edit: deleting an event (events are created in Calendar).
    var body: some View {
        VStack(alignment: .leading, spacing: tokens.space(.chipGap)) {
            if !plan.allDayEvents.isEmpty {
                AllDayStrip(events: plan.allDayEvents, font: .system(size: model.settings.timeline.eventFontSize - 2), onTap: style.onEventTap)
            }
            content.frame(maxHeight: .infinity)
        }
            .alert("event.delete.title", isPresented: Binding(get: { eventToDelete != nil }, set: { if !$0 { eventToDelete = nil } }),
                   presenting: eventToDelete) { event in
                Button("action.deleteEvent", role: .destructive) { Task { await model.deleteEvent(event) } }
                Button("common.cancel", role: .cancel) {}
            } message: { event in
                Text(L10n.format("event.delete.message", event.title))
            }
    }

    private var style: TimelineStyle {
        var style = TimelineStyle.make(model.settings.timeline, tokens: tokens)
        let prefix = model.config.rules.eventLinks.calendarAppURL
        style.onEventTap = { event in
            if let url = URL(string: "\(prefix)\(Int(event.start.timeIntervalSinceReferenceDate))") { openURL(url) }
        }
        let remindersURL = model.config.rules.eventLinks.remindersAppURL
        style.onReminderTap = { reminder in
            if let url = URL(string: remindersURL + reminder.id) { openURL(url) }
        }
        style.onEventDelete = { eventToDelete = $0 }
        style.onReminderToggle = { reminder in
            Haptics.play(.light)
            Task { await model.toggleReminder(reminder) }
        }
        return style
    }

    private func rollingWindow(_ settings: AppSettings.Timeline) -> TimelineWindow {
        TimelineWindow.rolling(now: plan.now, hoursBefore: settings.hoursBefore,
                               hoursAfter: min(settings.hoursAfter, model.config.rules.timeline.maxHoursAfter),
                               calendar: model.calendar)
    }

    /// The same row as in the pool, without chips: the title gets up to two lines.
    private func taskRow(_ item: DayItem, _ slot: TimelineSlot) -> some View {
        PoolRowContent(item: item, today: plan.today, isCompact: false, titleFont: .system(size: model.settings.timeline.taskFontSize),
                       showsDetails: false, titleLineLimit: 2, handler: handler)
    }
}
