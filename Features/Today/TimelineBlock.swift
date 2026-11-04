import SwiftUI

/// The timeline block. Stacked arrangement: one rolling column or two fixed halves; side by side:
/// hours around now or the whole day fitted into one column. Tapping an event opens Calendar. A "+" let go on the
/// one-column timeline opens a new task's page at that time.
struct TimelineBlock: View {
    @Environment(AppModel.self) private var model
    @Environment(Router.self) private var router
    @Environment(\.tokens) private var tokens
    @Environment(\.rules) private var rules
    @Environment(\.physicalBottom) private var physicalBottom
    @Environment(\.openURL) private var openURL
    @Environment(\.liftRoom) private var liftRoom
    @Environment(TaskDragState.self) private var drag: TaskDragState?
    @State private var eventToDelete: CalendarEvent?
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
    /// Where the hours start on the screen, for the dragged "+".
    @State private var hoursTop: CGFloat = 0

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
                                                rules: physicalBottom == nil ? model.config.rules.timeline.detail : model.config.rules.timeline.landscapeDetail)
                ScrollView {
                    DayTimelineView(slots: plan.timeline, window: day, now: plan.now,
                                    hourHeight: hourHeight, style: style(gridDetail: detail), taskContent: taskRow)
                        .modifier(TimelineDropTarget(drag: drag, moment: { y in
                            TaskScheduling.moment(atOffset: Double(y), windowStart: day.start, hourHeight: Double(hourHeight),
                                                  stepMinutes: model.config.rules.timeline.dropStepMinutes, calendar: model.calendar)
                        }, canDrop: { item, source in
                            // A worm dragged whole stays in the pool.
                            source.wormMembers.isEmpty && (!source.isBacklog || model.canBringFromBacklog(item.id))
                        }, onDrop: { item, source, moment in
                            Haptics.play(.drop)
                            Task {
                                if source.isBacklog { await model.scheduleFromBacklog(item.id, at: moment) }
                                else { await model.schedule(item.id, slot: source.slot, at: moment) }
                            }
                        }, onRefused: { model.refuseDrop($0.id, onto: .timeline) }))
                        .onGeometryChange(for: CGFloat.self) { $0.frame(in: .global).minY } action: { hoursTop = $0 }
                        .padding(.vertical, contentInset)
                        .padding(.trailing, nowLineOverhang)
                }
                .scrollPosition($position)
                .onChange(of: drag?.newItemPoint) { _, point in
                    newItemMoved(to: point, over: geometry.frame(in: .global), windowStart: day.start, hourHeight: hourHeight)
                }
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
                // The scroll reaches past the column so the now line is not cut at its edge; the content stays in it.
                .padding(.trailing, -nowLineOverhang)
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
                    .padding(.trailing, nowLineOverhang)
                }
                .contentMargins(.bottom, bottomInset + tokens.space(.scrollEndRoom), for: .scrollContent)
                .scrollBounceBehavior(.always)
                .scrollIndicators(.hidden)
                .syncsOnPull()
                .padding(.trailing, -nowLineOverhang)
            }
        }
    }

    /// The dragged "+" over the timeline: the spot shows next to the hours, and letting go opens a new task's page there.
    private func newItemMoved(to point: CGPoint?, over frame: CGRect, windowStart: Date, hourHeight: CGFloat) {
        guard let drag, let point else { return }
        guard frame.contains(point) else {
            drag.hoverMoment = nil
            drag.clearNewItemLanding(Self.newItemTarget)
            return
        }
        drag.turnAfterDwell(.block(.timeline), seconds: rules.gestures.newItemTurnDwellSeconds)
        let moment = TaskScheduling.moment(atOffset: Double(point.y - hoursTop), windowStart: windowStart,
                                           hourHeight: Double(hourHeight), stepMinutes: model.config.rules.timeline.dropStepMinutes,
                                           calendar: model.calendar)
        if drag.hover(at: moment) { Haptics.play(.dragStep) }
        drag.setNewItemLanding(Self.newItemTarget) { openNewItem(at: .timeline(at: moment, calendar: model.calendar)) }
    }

    private static let newItemTarget = "timeline"

    private func openNewItem(at placement: NewItemPlacement) {
        Haptics.play(.drop)
        router.openNewItem(NewItemSeed(kind: .task, placement: placement))
    }

    /// Half a group gap above the timeline's content and half below: a group gap in all, which the heights leave free.
    private var contentInset: CGFloat { tokens.space(.groupGap) / 2 }
    /// The now line ends halfway between the timeline's right edge and the screen's.
    private var nowLineOverhang: CGFloat { tokens.space(.screenHorizontal) / 2 }

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
        style.nowLineOverhang = nowLineOverhang
        style.dropMarker = drag?.hoverMoment
        if let item = drag?.item, let moment = drag?.hoverMoment {
            style.dropGhost = TimelineSlot.landing(item, at: moment, rules: model.config.rules.day)
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
    /// by its own time can be dragged to another time or back to the pool on any day; a habit's block too,
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
    let onRefused: (DayItem) -> Void

    func body(content: Content) -> some View {
        if let drag {
            // The empty space between the hours counts too: a drop target is only what is hit-testable.
            content
                .contentShape(Rectangle())
                .onDrop(of: TaskDragState.types, delegate: TimelineDropDelegate(drag: drag, moment: moment, canDrop: canDrop,
                                                                                onDrop: onDrop, onRefused: onRefused))
        } else {
            content
        }
    }
}
