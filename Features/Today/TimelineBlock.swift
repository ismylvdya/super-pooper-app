import SwiftUI

/// The timeline block. Stacked arrangement: one rolling column or two fixed halves; side by side:
/// hours around now or the whole day fitted into one column. Tapping an event opens Calendar.
struct TimelineBlock: View {
    @Environment(AppModel.self) private var model
    @Environment(\.tokens) private var tokens
    @Environment(\.openURL) private var openURL
    @Environment(TaskDragState.self) private var drag: TaskDragState?
    @State private var eventToDelete: CalendarEvent?
    @State private var highlightedSlot: String?
    let plan: DayPlan
    let handler: TaskActionHandler
    /// Space under the block that belongs to the home indicator (the timeline scrolls under it).
    let bottomInset: CGFloat

    @State private var zoom: CGFloat = 1
    @GestureState private var pinch: CGFloat = 1
    @State private var position = ScrollPosition(edge: .top)
    @State private var opening: TimelineOpening?
    @State private var pull: CGFloat = 0

    /// The whole logical day is always there to scroll through; the settings only choose what is shown
    /// first (hours around now, or the day range fitted to the height). Pinch zooms. Leaving Today
    /// resets both. All-day events and pull-to-refresh sit at the top of the same scroll.
    @ViewBuilder private var content: some View {
        let settings = model.settings.timeline
        switch model.settings.timelineMode {
        case .aroundNow, .wholeDay:
            GeometryReader { geometry in
                let context = model.context(at: plan.timelineFocus)
                let day = TimelineWindow(start: context.dayStart, end: context.dayEnd)
                let shown = model.settings.timelineMode == .wholeDay
                    ? TimelineWindow.fixed(start: settings.wholeDay.start, end: settings.wholeDay.end, context: context)
                    : rollingWindow(settings)
                let height = max(geometry.size.height - bottomInset - tokens.space(.groupGap), 1)
                let base = model.settings.timelineMode == .wholeDay
                    ? CGFloat(shown.hourHeight(fitting: Double(height)))
                    : tokens.size(.hourHeight)
                let hourHeight = base * min(max(zoom * pinch, tokens.size(.timelineZoomMin)), tokens.size(.timelineZoomMax))
                let stripHeight = plan.allDayEvents.isEmpty ? 0 : allDayHeight
                ScrollView {
                    DayTimelineView(slots: plan.timeline, window: day, now: plan.now,
                                    hourHeight: hourHeight, style: style, taskContent: taskRow)
                        .modifier(TimelineDropTarget(drag: drag, moment: { y in
                            TaskScheduling.moment(atOffset: Double(y), windowStart: day.start, hourHeight: Double(hourHeight),
                                                  stepMinutes: model.config.rules.timeline.dropStepMinutes, calendar: model.calendar)
                        }, onDrop: { item, moment in
                            Haptics.play(.light)
                            Task { await model.schedule(item.id, at: moment) }
                        }))
                        .padding(.vertical, tokens.space(.groupGap) / 2)
                }
                .scrollPosition($position)
                .contentMargins(.top, stripHeight, for: .scrollContent)
                .contentMargins(.bottom, bottomInset, for: .scrollContent)
                .onScrollGeometryChange(for: CGFloat.self) { max(0, -($0.contentOffset.y + $0.contentInsets.top)) } action: { _, new in
                    pull = new
                }
                .scrollBounceBehavior(.always)
                .scrollIndicators(.hidden)
                .refreshable { await model.sync(announce: true) }
                .edgeFades(bottomExtension: bottomInset)
                .liftRoom()
                .simultaneousGesture(
                    MagnifyGesture()
                        .updating($pinch) { value, state, _ in state = value.magnification }
                        .onEnded { value in
                            zoom = min(max(zoom * value.magnification, tokens.size(.timelineZoomMin)), tokens.size(.timelineZoomMax))
                        }
                )
                // All-day events stay put over the hours; they move down only with a pull to refresh.
                .overlay(alignment: .top) {
                    if !plan.allDayEvents.isEmpty {
                        allDayStrip
                            .padding(.bottom, tokens.space(.chipGap))
                            .background(tokens.color(.screenBackground))
                            .offset(y: pull)
                    }
                }
                .onAppear {
                    zoom = 1
                    let start = day.offset(of: shown.start, hourHeight: Double(base))
                    let opened = TimelineOpening(startOffset: start, stripHeight: Double(stripHeight))
                    opening = opened
                    position.scrollTo(y: CGFloat(opened.offset))
                }
                .onChange(of: stripHeight) { _, height in
                    if let offset = opening?.stripChanged(to: Double(height)) { position.scrollTo(y: CGFloat(offset)) }
                }
                .onScrollPhaseChange { _, phase in
                    if phase == .interacting { opening?.userScrolled() }
                }
            }
        case .halves:
            GeometryReader { geometry in
                ScrollView {
                    VStack(alignment: .leading, spacing: tokens.space(.chipGap)) {
                        if !plan.allDayEvents.isEmpty { allDayStrip }
                        HalvesTimeline(plan: plan, settings: settings, context: model.context(at: plan.timelineFocus),
                                       height: geometry.size.height - bottomInset - tokens.space(.groupGap),
                                       style: style, taskContent: taskRow)
                    }
                    .padding(.vertical, tokens.space(.groupGap) / 2)
                }
                .contentMargins(.bottom, bottomInset, for: .scrollContent)
                .scrollBounceBehavior(.always)
                .scrollIndicators(.hidden)
                .refreshable { await model.sync(announce: true) }
            }
        }
    }

    /// All-day bars are a little smaller than the event titles.
    private var allDayFontSize: CGFloat { model.settings.timeline.eventFontSize - tokens.size(.allDayFontDelta) }

    private var allDayStrip: some View {
        AllDayStrip(events: plan.allDayEvents, font: .system(size: allDayFontSize), lineHeight: UIFont.systemFont(ofSize: allDayFontSize).lineHeight,
                    onTap: style.onEventTap, onDelete: style.onEventDelete)
    }

    private var allDayHeight: CGFloat {
        let line = UIFont.systemFont(ofSize: allDayFontSize).lineHeight + tokens.space(.chipVertical) * 2
        return CGFloat(plan.allDayEvents.count) * (line + tokens.space(.chipGap)) + tokens.space(.chipGap)
    }

    /// The block with the dialog for the one timeline edit: deleting an event (events are created in Calendar).
    var body: some View {
        content.frame(maxHeight: .infinity)
            .alert("event.delete.title", isPresented: Binding(presenting: $eventToDelete),
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
        style.rowsHaveOwnPlates = true
        style.showsNow = plan.isToday
        style.highlightedSlot = highlightedSlot
        style.dropMarker = drag?.hoverMoment
        style.onLinkTap = { slot in
            Haptics.play(.light)
            withAnimation(tokens.animation) { highlightedSlot = highlightedSlot == slot.id ? nil : slot.id }
        }
        style.onReminderToggle = { reminder in
            Haptics.play(.light)
            Task { await model.toggleReminder(reminder) }
        }
        return style
    }

    private func rollingWindow(_ settings: AppSettings.Timeline) -> TimelineWindow {
        TimelineWindow.rolling(now: plan.timelineFocus, hoursBefore: settings.hoursBefore,
                               hoursAfter: min(settings.hoursAfter, model.config.rules.timeline.maxHoursAfter),
                               calendar: model.calendar)
    }

    /// The same row as in the pool, without chips: the title gets up to two lines. A task on the timeline
    /// by its own time (not a habit, not a chain) can be dragged to another time or back to the pool.
    private func taskRow(_ item: DayItem, _ slot: TimelineSlot) -> some View {
        let movable = slot.time != nil && TaskScheduling.canMove(item.task)
        return PoolRowContent(item: item, today: plan.today, isCompact: false, titleFont: .system(size: model.settings.timeline.taskFontSize),
                              showsDetails: false, titleLineLimit: 2,
                              titleLineHeight: UIFont.systemFont(ofSize: model.settings.timeline.taskFontSize).lineHeight,
                              plate: .slot(isPast: slot.isPast, isCompact: false), handler: handler,
                              dragSource: movable ? .timeline : nil)
    }
}

/// The one-column timeline as a drop target for tasks.
private struct TimelineDropTarget: ViewModifier {
    let drag: TaskDragState?
    let moment: (CGFloat) -> Date
    let onDrop: (DayItem, Date) -> Void

    func body(content: Content) -> some View {
        if let drag {
            // The empty space between the hours counts too: a drop target is only what is hit-testable.
            content
                .contentShape(Rectangle())
                .onDrop(of: TaskDragState.types, delegate: TimelineDropDelegate(drag: drag, moment: moment, onDrop: onDrop))
        } else {
            content
        }
    }
}
