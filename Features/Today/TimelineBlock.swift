import SwiftUI

/// The timeline block. Stacked arrangement: one rolling column or two fixed halves; side by side:
/// hours around now or the whole day fitted into one column. Tapping an event opens Calendar.
struct TimelineBlock: View {
    @Environment(AppModel.self) private var model
    @Environment(\.tokens) private var tokens
    @Environment(\.rules) private var rules
    @Environment(\.openURL) private var openURL
    @Environment(\.liftRoom) private var liftRoom
    @Environment(TaskDragState.self) private var drag: TaskDragState?
    @State private var eventToDelete: CalendarEvent?
    @State private var highlightedSlot: String?
    let plan: DayPlan
    let handler: TaskActionHandler
    /// Space under the block that belongs to the home indicator (the timeline scrolls under it).
    let bottomInset: CGFloat
    /// The edges of the timeline that lie under a system bar (`edgeFades`).
    let barEdges: Edge.Set

    @State private var zoom: CGFloat = 1
    @GestureState private var pinch: CGFloat = 1
    /// Where a pinch began: the scroll offset, the height between the fingers and the hour height then.
    @State private var pinchStart: (offset: CGFloat, y: CGFloat, hourHeight: CGFloat)?
    @State private var scrollOffset: CGFloat = 0
    @State private var position = ScrollPosition(edge: .top)
    @State private var opening: TimelineOpening?
    @State private var pull: CGFloat = 0

    /// The whole logical day is always there to scroll through; the settings only choose what is shown
    /// first (hours around now, or the day range fitted to the height). Pinch zooms around the point between the
    /// fingers. Leaving Today resets both. All-day events and pull-to-refresh sit at the top of the same scroll; the
    /// hours dissolve under the all-day strip, whose top is level with the pool's first row.
    @ViewBuilder private var content: some View {
        let settings = model.settings.timeline
        switch model.settings.timelineMode {
        case .aroundNow, .wholeDay:
            GeometryReader { geometry in
                let context = model.context(at: plan.timelineFocus)
                let day = TimelineWindow(start: context.dayStart, end: context.dayEnd)
                let shown = windows(context).first ?? day
                let height = max(geometry.size.height - bottomInset - tokens.space(.groupGap), 1)
                let base = model.settings.timelineMode == .wholeDay
                    ? CGFloat(shown.hourHeight(fitting: Double(height)))
                    : tokens.size(.hourHeight)
                let scale = { (factor: CGFloat) in base * min(max(factor, zoomLimits.min), zoomLimits.max) }
                let hourHeight = scale(zoom * pinch)
                let stripRoom = stripHeight == 0 ? 0 : stripHeight + tokens.space(.chipGap) * 2
                let detail = TimelineGridDetail(visibleHours: Double(geometry.size.height / hourHeight),
                                                rules: model.config.rules.timeline.detail)
                ScrollView {
                    DayTimelineView(slots: plan.timeline, window: day, now: plan.now,
                                    hourHeight: hourHeight, style: style(gridDetail: detail), taskContent: taskRow)
                        .modifier(TimelineDropTarget(drag: drag, moment: { y in
                            TaskScheduling.moment(atOffset: Double(y), windowStart: day.start, hourHeight: Double(hourHeight),
                                                  stepMinutes: model.config.rules.timeline.dropStepMinutes, calendar: model.calendar)
                        }, canDrop: { item, source in
                            // A worm dragged whole stays in the pool.
                            source.wormMembers.isEmpty && (source.isBacklog ? model.canBringFromBacklog(item.id)
                                : model.canDropOnTimeline(item.id, slot: source.slot, on: plan.today))
                        }, onDrop: { item, source, moment in
                            Haptics.play(.drop)
                            Task {
                                if source.isBacklog { await model.scheduleFromBacklog(item.id, at: moment) }
                                else { await model.schedule(item.id, slot: source.slot, at: moment) }
                            }
                        }))
                        .padding(.vertical, contentInset)
                }
                .scrollPosition($position)
                .contentMargins(.bottom, bottomInset + tokens.space(.scrollEndRoom), for: .scrollContent)
                .onScrollGeometryChange(for: CGFloat.self) { max(0, -($0.contentOffset.y + $0.contentInsets.top)) } action: { _, new in
                    pull = new
                }
                // Counted from the scroll's top position, as `scrollTo(y:)` takes it.
                .onScrollGeometryChange(for: CGFloat.self) { $0.contentOffset.y + $0.contentInsets.top } action: { _, new in scrollOffset = new }
                .scrollBounceBehavior(.always)
                .scrollIndicators(.hidden)
                .syncsOnPull()
                // The hours dissolve from the strip's bottom down.
                .edgeFades(topInset: stripHeight == 0 ? 0 : liftRoom.top + stripHeight + pull, bottomExtension: bottomInset,
                           barEdges: barEdges)
                .liftRoom(extraTop: stripRoom)
                .simultaneousGesture(
                    MagnifyGesture()
                        .updating($pinch) { value, state, _ in state = value.magnification }
                        .onChanged { value in
                            let start = pinchStart ?? (scrollOffset, value.startLocation.y, scale(zoom))
                            pinchStart = start
                            // The hours start under the top margin (the lift room and the all-day strip) and the padding.
                            let hoursTop = liftRoom.top + stripRoom + contentInset
                            let offset = TimelineZoom.offset(keeping: Double(start.y), startOffset: Double(start.offset),
                                                             contentTop: Double(hoursTop), from: Double(start.hourHeight),
                                                             to: Double(scale(zoom * value.magnification)))
                            position.scrollTo(y: CGFloat(offset))
                        }
                        .onEnded { value in
                            zoom = min(max(zoom * value.magnification, zoomLimits.min), zoomLimits.max)
                            pinchStart = nil
                        }
                )
                // All-day events stay put over the hours, their top level with the pool's first row; they move down
                // only with a pull to refresh.
                .overlay(alignment: .top) {
                    if !plan.allDayEvents.isEmpty {
                        allDayStrip
                            .padding(.top, liftRoom.top)
                            .background(tokens.color(.screenBackground))
                            .offset(y: pull)
                    }
                }
                .onAppear {
                    zoom = 1
                    let start = day.offset(of: shown.start, hourHeight: Double(base))
                    let opened = TimelineOpening(startOffset: start, stripHeight: Double(stripRoom))
                    opening = opened
                    position.scrollTo(y: CGFloat(opened.offset))
                }
                .onChange(of: stripRoom) { _, height in
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
                        HalvesTimeline(plan: plan, windows: windows(model.context(at: plan.timelineFocus)), settings: settings,
                                       height: geometry.size.height - bottomInset - tokens.space(.groupGap),
                                       style: style, taskContent: taskRow)
                    }
                    .padding(.vertical, contentInset)
                }
                .contentMargins(.bottom, bottomInset + tokens.space(.scrollEndRoom), for: .scrollContent)
                .scrollBounceBehavior(.always)
                .scrollIndicators(.hidden)
                .syncsOnPull()
            }
        }
    }

    /// Half a group gap above the timeline's content and half below: a group gap in all, which the heights leave free.
    private var contentInset: CGFloat { tokens.space(.groupGap) / 2 }

    private var zoomLimits: (min: CGFloat, max: CGFloat) { (CGFloat(rules.timeline.zoom.min), CGFloat(rules.timeline.zoom.max)) }
    private var fonts: TimelineFonts { .app(model.settings.timeline, tokens: tokens) }

    private var allDayStrip: some View {
        AllDayStrip(events: plan.allDayEvents, font: fonts.allDay, lineHeight: fonts.allDayLineHeight,
                    onTap: style.onEventTap, onDelete: style.onEventDelete)
    }

    /// The all-day strip as it is drawn; 0 without all-day events. The hours start two bar gaps under it.
    private var stripHeight: CGFloat {
        AllDayStrip.height(count: plan.allDayEvents.count, lineHeight: fonts.allDayLineHeight, tokens: tokens)
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

    private var style: TimelineStyle { style(gridDetail: .none) }

    /// The app's timeline; zoomed in, it shows `gridDetail`.
    private func style(gridDetail: TimelineGridDetail) -> TimelineStyle {
        var style = TimelineStyle.make(model.settings.timeline, tokens: tokens)
        style.gridDetail = gridDetail
        let links = model.config.rules.eventLinks
        style.onEventTap = { event in
            if let url = links.calendarURL(at: event.start) { openURL(url) }
        }
        style.onReminderTap = { reminder in
            if let url = links.reminderURL(id: reminder.id) { openURL(url) }
        }
        style.onEventDelete = { eventToDelete = $0 }
        style.rowsHaveOwnPlates = true
        style.showsNow = plan.isToday
        style.highlightedSlot = highlightedSlot
        style.dropMarker = drag?.hoverMoment
        if let item = drag?.item, let moment = drag?.hoverMoment {
            style.dropGhost = TimelineSlot.landing(item, at: moment, rules: model.config.rules.day)
        }
        style.onLinkTap = { slot in
            Haptics.play(.select)
            withAnimation(tokens.animation) { highlightedSlot = highlightedSlot == slot.id ? nil : slot.id }
        }
        style.onReminderToggle = { reminder in
            Haptics.play(.mark)
            Task { await model.toggleReminder(reminder) }
        }
        return style
    }

    /// What the settings show first (around now, the day range) or the two halves.
    private func windows(_ context: DayContext) -> [TimelineWindow] {
        let span = model.settings.timelineSpan(limits: TimelineSpan.Limits(hoursAfter: model.config.rules.timeline.maxHoursAfter))
        return TimelineWindow.windows(span, around: plan.timelineFocus, context: context)
    }

    /// The same row as in the pool, without chips or a done mark, always on one line (a long title dissolves): what is
    /// finished has left the timeline, what is on it is shown plainly (a twice-a-day habit after its first Done too). A task on the timeline
    /// by its own time (not a chain) can be dragged to another time or back to the pool on any day; a habit's block too,
    /// for that day only.
    private func taskRow(_ item: DayItem, _ slot: TimelineSlot) -> some View {
        let movable = slot.time != nil
        return PoolRowContent(item: item, isToday: plan.isToday, isCompact: false, titleFont: fonts.task,
                              showsDetails: false, titleLineLimit: 1, titleLineHeight: fonts.taskLineHeight,
                              showsDoneState: false, plate: .slot(isPast: slot.isPast, isCompact: false), handler: handler,
                              dragSource: movable ? .timeline(slot: slot.time) : nil)
    }
}

/// The one-column timeline as a drop target for tasks and habit blocks.
private struct TimelineDropTarget: ViewModifier {
    let drag: TaskDragState?
    let moment: (CGFloat) -> Date
    let canDrop: (DayItem, TaskDragState.Source) -> Bool
    let onDrop: (DayItem, TaskDragState.Source, Date) -> Void

    func body(content: Content) -> some View {
        if let drag {
            // The empty space between the hours counts too: a drop target is only what is hit-testable.
            content
                .contentShape(Rectangle())
                .onDrop(of: TaskDragState.types, delegate: TimelineDropDelegate(drag: drag, moment: moment, canDrop: canDrop,
                                                                                onDrop: onDrop))
        } else {
            content
        }
    }
}
