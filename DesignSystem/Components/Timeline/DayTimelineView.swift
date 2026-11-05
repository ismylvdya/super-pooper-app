import SwiftUI
import WidgetKit

/// One timeline column: hour grid, blocks laid out side by side when they overlap, "now" line.
/// Shared by the Today screen, the settings preview and the widget.
struct DayTimelineView<TaskContent: View>: View {
    @Environment(\.tokens) private var tokens
    @Environment(\.icons) private var icons
    @Environment(\.timelineBell) private var bell
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.calendar) private var calendar
    @Environment(\.rules) private var rules
    let slots: [TimelineSlot]
    let window: TimelineWindow
    let now: Date
    let hourHeight: CGFloat
    let style: TimelineStyle
    @ViewBuilder let taskContent: (DayItem, TimelineSlot) -> TaskContent

    var body: some View {
        let placements = layout.place(slots)
        GeometryReader { geometry in
            let itemsWidth = max(geometry.size.width - labelWidth, 0)
            let blocks = placements.map { PlacedSlot($0, width: itemsWidth, indentStep: tokens.space(.timelineCascadeIndent)) }
            ZStack(alignment: .topLeading) {
                hourGrid(width: geometry.size.width)
                TimelineFineGrid(hours: hourMarks, detail: style.gridDetail, labelWidth: style.showsHourLabels ? labelWidth : 0,
                                 width: geometry.size.width, labelHeight: hourLabelHeight, y: y)
                ForEach(blocks) { item in
                    block(for: item.slot)
                        .environment(\.titleReserve, item.slot.hasAlarm ? alarmInset + alarmMark : cornerWidth(bell: item.slot.showsBell))
                        .overlay(alignment: .topTrailing) {
                            HStack(spacing: tokens.space(.cornerMarkGap)) {
                                if item.slot.showsBell { AlertBell(color: bellColor(of: item.slot)) }
                            }
                            .padding(.top, cornerInset)
                            .padding(.trailing, cornerInset)
                        }
                        .overlay(alignment: .topTrailing) {
                            if item.slot.hasAlarm {
                                AlertBell(isAlarm: true, sizedAsBell: style.compactPlates)
                                    .padding(.top, alarmInset)
                                    .padding(.trailing, alarmInset)
                            }
                        }
                        .frame(width: max(item.frame.width - tokens.space(.timelineItemGap), 0),
                               height: max(item.frame.height - tokens.space(.timelineItemGap), 0), alignment: .topLeading)
                        .offset(x: labelWidth + item.frame.minX, y: item.frame.minY)
                }
                if style.showsNow, window.contains(now) { nowLine(width: geometry.size.width, blocks: blocks) }
                if let ghost = style.dropGhost, window.contains(ghost.start) { dropGhost(ghost, width: itemsWidth) }
                if let marker = style.dropMarker, window.contains(marker) {
                    TimelineDropMarker(moment: marker, labelWidth: labelWidth, width: geometry.size.width).offset(y: y(marker))
                }
            }
        }
        .frame(height: max(totalHeight, CGFloat(placements.map(\.bottom).max() ?? 0)))
    }

    /// Dense widget plates: the bell sits as far from the right edge as from the top and bottom of a one-line block.
    private var cornerInset: CGFloat {
        style.compactPlates ? max((style.minimumItemHeight - tokens.space(.timelineItemGap) - bell.size) / 2, tokens.size(.cornerInsetMinimum)) : tokens.space(.bellInset)
    }

    /// How far from the block's right edge the corner marks reach (their inset and the bell); 0 without one. The title fades out `fadeGap` before that (`TitleFade`).
    private func cornerWidth(bell showsBell: Bool) -> CGFloat {
        showsBell ? cornerInset + bell.size : 0
    }

    /// On a one-line block the alarm's mark stands as far from the right edge as from the top and the bottom.
    private var alarmInset: CGFloat {
        max(((style.minimumTaskHeight ?? style.minimumItemHeight) - tokens.space(.timelineItemGap) - alarmMark) / 2, 0)
    }

    /// In a widget as big as the bells beside it.
    private var alarmMark: CGFloat { style.compactPlates ? bell.size : tokens.size(.alarmMark) }

    /// The hour column and the hour labels' line grow with the hour font.
    private var labelWidth: CGFloat { style.showsHourLabels ? tokens.hourColumnWidth : 0 }
    private var hourLabelHeight: CGFloat { tokens.scaled(tokens.size(.hourLabelHeight), with: .timelineHour) }
    private var totalHeight: CGFloat { CGFloat(window.hours) * hourHeight }

    private func y(_ date: Date) -> CGFloat {
        CGFloat(window.offset(of: date, hourHeight: Double(hourHeight)))
    }

    /// Where the blocks go (`TimelineBlockLayout`), worked out once per drawing.
    private var layout: TimelineBlockLayout {
        TimelineBlockLayout(window: window, hourHeight: Double(hourHeight), minimumEventHeight: Double(style.minimumItemHeight),
                            minimumTaskHeight: Double(style.minimumTaskHeight ?? style.minimumItemHeight),
                            titleRoomShare: Double(tokens.ratio(.timelineTitleRoom)))
    }

    /// A placed block in a column of the drawn width.
    private struct PlacedSlot: Identifiable {
        let slot: TimelineSlot
        let frame: CGRect
        var id: String { slot.id }

        init(_ placement: TimelineBlockLayout.Placement, width: CGFloat, indentStep: CGFloat) {
            let horizontal = placement.horizontal(in: Double(width), indentStep: Double(indentStep))
            slot = placement.slot
            frame = CGRect(x: horizontal.x, y: placement.top, width: horizontal.width, height: placement.height)
        }
    }

    @ViewBuilder private func block(for slot: TimelineSlot) -> some View {
        switch slot.content {
        case .event(let event):
            if let onEventTap = style.onEventTap {
                // A tap, not a Button: a button also fires when a swipe across the timeline ends on the event.
                TimelineEventBlock(event: event, slot: slot, font: style.fonts.event, lineHeight: style.fonts.eventLineHeight)
                    .backdrop(style.backdrop, cornerRadius: cornerRadius(of: slot))
                    .contentShape(Rectangle())
                    .onTapGesture { onEventTap(event) }
                    .accessibilityAddTraits(.isButton)
                    .accessibilityAction { onEventTap(event) }
                    .plateLift(.timelineItem, for: .contextMenuPreview)
                    .contextMenu {
                        if let onEventDelete = style.onEventDelete { RegistryMenu(menu: .eventContext) { _ in onEventDelete(event) } }
                    }
            } else {
                TimelineEventBlock(event: event, slot: slot, font: style.fonts.event, lineHeight: style.fonts.eventLineHeight)
            }
        case .reminder(let reminder):
            TimelineReminderBlock(reminder: reminder, slot: slot, font: style.fonts.task, lineHeight: style.fonts.taskLineHeight,
                                  isCompact: style.compactPlates, backdrop: style.backdrop,
                                  onToggle: style.onReminderToggle, onOpen: style.onReminderTap)
        case .task(let item):
            if style.rowsHaveOwnPlates {
                taskContent(item, slot)
            } else {
                TimelineTaskBlock(isPast: slot.isPast, isCompact: style.compactPlates) { taskContent(item, slot) }
            }
        }
    }

    /// The faint copy of the dragged plate where it would land: across the column, as tall as its block would be.
    private func dropGhost(_ slot: TimelineSlot, width: CGFloat) -> some View {
        let gap = tokens.space(.timelineItemGap)
        let height = max(y(slot.end) - y(slot.start), style.minimumTaskHeight ?? style.minimumItemHeight)
        return block(for: slot)
            .frame(width: max(width - gap, 0), height: max(height - gap, 0), alignment: .topLeading)
            .offset(x: labelWidth, y: y(slot.start))
            .dropGhost()
    }

    /// Hours as plain numbers ("9", "14"), centered on one vertical next to the grid line.
    private func hourGrid(width: CGFloat) -> some View {
        ForEach(hourMarks, id: \.self) { mark in
            HStack(alignment: .center, spacing: tokens.space(.hourLabelGap)) {
                if style.showsHourLabels {
                    Text(verbatim: "\(calendar.component(.hour, from: mark))")
                        .font(tokens.font(.timelineHour).monospacedDigit())
                        .foregroundStyle(tokens.color(.tertiaryText))
                        // "9" and "14" share one vertical, which the now dot and the all-day icon stand on.
                        .frame(width: tokens.hourDigitsWidth)
                        .frame(width: labelWidth - tokens.space(.hourLabelGap), alignment: .trailing)
                }
                Rectangle().fill(tokens.color(.timelineGrid)).frame(height: tokens.size(.gridLine))
            }
            .frame(width: width, height: hourLabelHeight)
            .offset(y: y(mark) - hourLabelHeight / 2)
        }
    }

    private var hourMarks: [Date] {
        var marks: [Date] = []
        var cursor = calendar.dateInterval(of: .hour, for: window.start)?.start ?? window.start
        if cursor < window.start { cursor = cursor.addingTimeInterval(TimelineWindow.hour) }
        while cursor <= window.end {
            marks.append(cursor)
            cursor = cursor.addingTimeInterval(TimelineWindow.hour)
        }
        return marks
    }

    /// The corners the now line is cut out by: an event's own, or the plate of a task or reminder
    /// (smaller in widgets).
    private func cornerRadius(of slot: TimelineSlot) -> CGFloat {
        if case .event = slot.content { return tokens.plateRadius(.timelineItem) }
        // The same plate in the app and in widgets; a short slot is capped by `PlateShape`.
        return tokens.plateRadius(.row)
    }

    /// An event's bell is in its time's color; a finished event's as its text.
    private func bellColor(of slot: TimelineSlot) -> Color? {
        guard case .event(let event) = slot.content else { return nil }
        return slot.isPast ? tokens.color(.secondaryText) : tokens.eventSecondary(Color(hex: event.colorHex), in: colorScheme)
    }

    /// The "now" cursor, as in the old Calendar widget: a dot in the middle of the hour numbers and a
    /// line from its center to the right edge with a rounded end; over blocks it is more see-through.
    private func nowLine(width: CGFloat, blocks: [PlacedSlot]) -> some View {
        let dot = tokens.size(.nowDot)
        let centerX = style.showsHourLabels ? tokens.hourDigitsCenter : dot / 2
        let origin = CGPoint(x: centerX - dot / 2, y: y(now) - dot / 2)
        let gap = tokens.space(.timelineItemGap)
        let covered = blocks.map { block in
            (rect: CGRect(x: labelWidth + block.frame.minX - origin.x, y: block.frame.minY - origin.y,
                          width: max(block.frame.width - gap, 0), height: max(block.frame.height - gap, 0)),
             radius: cornerRadius(of: block.slot))
        }
        let overBlocks = tokens.opacity(.nowOverBlocks)
        return ZStack(alignment: .leading) {
            UnevenRoundedRectangle(bottomTrailingRadius: tokens.size(.nowLine) / 2, topTrailingRadius: tokens.size(.nowLine) / 2)
                .frame(height: tokens.size(.nowLine))
                .padding(.leading, dot / 2)
            Circle().frame(width: dot, height: dot)
        }
        .foregroundStyle(tokens.color(.nowLine))
        .widgetAccentable()
        .mask {
            Canvas { context, size in
                context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(.black))
                context.blendMode = .destinationOut
                for block in covered {
                    context.fill(PlateShape(cornerRadius: block.radius).path(in: block.rect),
                                 with: .color(.black.opacity(1 - overBlocks)))
                }
            }
        }
        .frame(width: width - origin.x + style.nowLineOverhang, height: dot)
        .offset(x: origin.x, y: origin.y)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

private extension View {
    /// An opaque backing under a see-through plate: a block lying over an earlier one hides it, and a long press lifts the
    /// plate itself, not an outline of it (the lift keeps only what the menu's view draws).
    @ViewBuilder func backdrop(_ color: Color?, cornerRadius: CGFloat) -> some View {
        if let color { background { PlateShape(cornerRadius: cornerRadius).fill(color) } } else { self }
    }
}
