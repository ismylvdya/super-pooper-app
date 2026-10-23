import SwiftUI

/// One timeline column: hour grid, blocks laid out side by side when they overlap, "now" line.
/// Shared by the Today screen, the settings preview and the widget.
struct DayTimelineView<TaskContent: View>: View {
    @Environment(\.tokens) private var tokens
    @Environment(\.icons) private var icons
    let slots: [TimelineSlot]
    let window: TimelineWindow
    let now: Date
    let hourHeight: CGFloat
    let style: TimelineStyle
    @ViewBuilder let taskContent: (DayItem, TimelineSlot) -> TaskContent

    var body: some View {
        GeometryReader { geometry in
            let itemsWidth = max(geometry.size.width - labelWidth, 0)
            ZStack(alignment: .topLeading) {
                createLayer
                hourGrid(width: geometry.size.width)
                ForEach(placed(width: itemsWidth)) { item in
                    block(for: item.slot)
                        .frame(width: max(item.frame.width - tokens.space(.timelineItemGap), 0),
                               height: max(item.frame.height - tokens.space(.timelineItemGap), 0), alignment: .topLeading)
                        .offset(x: labelWidth + item.frame.minX, y: item.frame.minY)
                }
                if window.contains(now) { nowLine(width: geometry.size.width) }
            }
        }
        .frame(height: max(totalHeight, contentBottom))
    }

    /// Long press on an empty spot starts a new event at that time (blocks above it handle their own touches).
    @ViewBuilder private var createLayer: some View {
        if let onCreateAt = style.onCreateAt {
            Color.clear
                .contentShape(Rectangle())
                .gesture(LongPressGesture(minimumDuration: 0.5)
                    .sequenced(before: DragGesture(minimumDistance: 0))
                    .onEnded { value in
                        guard case .second(true, let drag?) = value else { return }
                        onCreateAt(date(atY: drag.location.y))
                    })
        }
    }

    private func date(atY y: CGFloat) -> Date {
        window.start.addingTimeInterval(Double(y / hourHeight) * 3600)
    }

    private var contentBottom: CGFloat { CGFloat(placed(width: 1).map(\.frame.maxY).max() ?? 0) }

    private var labelWidth: CGFloat { style.showsHourLabels ? tokens.space(.timelineLabelWidth) : 0 }
    private var totalHeight: CGFloat { CGFloat(window.duration / 3600) * hourHeight }

    private func y(_ date: Date) -> CGFloat {
        CGFloat(date.timeIntervalSince(window.start) / 3600) * hourHeight
    }

    private struct PlacedSlot: Identifiable {
        let slot: TimelineSlot
        let frame: CGRect
        var id: String { slot.id }
    }

    /// Blocks get at least the minimum height. A block that does not overlap an earlier one in time
    /// but would overlap it visually is pushed below it (so short chains read top to bottom);
    /// blocks that really overlap in time share the width in columns, like in Calendar.
    private func placed(width: CGFloat) -> [PlacedSlot] {
        let visible = slots.filter { $0.end > window.start && $0.start < window.end }
            .sorted { $0.start != $1.start ? $0.start < $1.start : $0.end > $1.end }
        var extents: [(start: Double, end: Double)] = []
        for (index, slot) in visible.enumerated() {
            var top = y(max(slot.start, window.start))
            let height = max(y(min(slot.end, window.end)) - top, minimumHeight(of: slot))
            for earlier in visible.indices where earlier < index && visible[earlier].end <= slot.start {
                top = max(top, CGFloat(extents[earlier].end))
            }
            extents.append((Double(top), Double(top + height)))
        }
        let placements = ColumnAssigner.assign(extents)
        return zip(visible, zip(extents, placements)).map { slot, pair in
            let (extent, placement) = pair
            let columnWidth = width / CGFloat(placement.columnCount)
            return PlacedSlot(slot: slot, frame: CGRect(x: CGFloat(placement.column) * columnWidth, y: extent.start,
                                                        width: columnWidth, height: extent.end - extent.start))
        }
    }

    private func minimumHeight(of slot: TimelineSlot) -> CGFloat {
        switch slot.content {
        case .task, .reminder: return style.minimumTaskHeight ?? style.minimumItemHeight
        case .event: break
        }
        return style.minimumItemHeight
    }

    @ViewBuilder private func block(for slot: TimelineSlot) -> some View {
        switch slot.content {
        case .event(let event):
            if let onEventTap = style.onEventTap {
                Button { onEventTap(event) } label: { TimelineEventBlock(event: event, slot: slot, font: style.eventFont) }
                    .buttonStyle(.plain)
                    .contextMenu {
                        if let onEventDelete = style.onEventDelete {
                            Button(role: .destructive) { onEventDelete(event) } label: {
                                Label(LocalizedStringKey("action.deleteEvent"), systemImage: icons[.delete])
                            }
                        }
                    }
            } else {
                TimelineEventBlock(event: event, slot: slot, font: style.eventFont)
            }
        case .reminder(let reminder):
            TimelineReminderBlock(reminder: reminder, slot: slot, font: style.taskFont,
                                  isCompact: style.compactPlates,
                                  onToggle: style.onReminderToggle, onOpen: style.onReminderTap)
        case .task(let item): TimelineTaskBlock(item: item, isPast: slot.isPast, isCompact: style.compactPlates) { taskContent(item, slot) }
        }
    }

    private func hourGrid(width: CGFloat) -> some View {
        ForEach(hourMarks, id: \.self) { mark in
            HStack(alignment: .center, spacing: 4) {
                if style.showsHourLabels {
                    Text(mark.formatted(.dateTime.hour()))
                        .font(tokens.font(.timelineHour))
                        .foregroundStyle(tokens.color(.tertiaryText))
                        .frame(width: labelWidth - 4, alignment: .leading)
                }
                Rectangle().fill(tokens.color(.timelineGrid)).frame(height: 0.5)
            }
            .frame(width: width, height: 12)
            .offset(y: y(mark) - 6)
        }
    }

    private var hourMarks: [Date] {
        var marks: [Date] = []
        var cursor = Calendar.current.dateInterval(of: .hour, for: window.start)?.start ?? window.start
        if cursor < window.start { cursor = cursor.addingTimeInterval(3600) }
        while cursor <= window.end {
            marks.append(cursor)
            cursor = cursor.addingTimeInterval(3600)
        }
        return marks
    }

    private func nowLine(width: CGFloat) -> some View {
        HStack(spacing: 0) {
            Circle().fill(tokens.color(.nowLine)).frame(width: tokens.size(.nowDot), height: tokens.size(.nowDot))
            Rectangle().fill(tokens.color(.nowLine)).frame(height: tokens.size(.nowLine))
        }
        .frame(width: width - labelWidth + tokens.size(.nowDot) / 2)
        .offset(x: labelWidth - tokens.size(.nowDot) / 2, y: y(now) - tokens.size(.nowDot) / 2)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

/// Visual parameters of a timeline column.
struct TimelineStyle {
    var eventFont: Font
    var taskFont: Font
    /// At least one line of normal text.
    var minimumItemHeight: CGFloat
    /// Tasks get at least their title and chip lines (short tasks still show two lines).
    var minimumTaskHeight: CGFloat?
    var showsHourLabels = true
    /// Tap on an event (the app opens Calendar on that day).
    var onEventTap: ((CalendarEvent) -> Void)?
    /// Long-press menu of an event (asks first) and long press on an empty spot (a new event at that time).
    var onEventDelete: ((CalendarEvent) -> Void)?
    var onCreateAt: ((Date) -> Void)?
    /// Reminder long-press menu (completes it in Reminders) and tap (opens it in Reminders).
    var onReminderToggle: ((ReminderItem) -> Void)?
    var onReminderTap: ((ReminderItem) -> Void)?
    /// Dense widget timelines: plates with minimal vertical padding.
    var compactPlates = false
}
