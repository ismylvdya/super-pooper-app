import SwiftUI

/// A calendar event: tinted fill with the calendar color stripe (distinct from tasks).
struct TimelineEventBlock: View {
    @Environment(\.tokens) private var tokens
    let event: CalendarEvent
    let slot: TimelineSlot
    let font: Font

    var body: some View {
        let color = slot.isPast ? tokens.color(.past) : Color(hex: event.colorHex)
        HStack(spacing: tokens.space(.timelineItemPadding)) {
            RoundedRectangle(cornerRadius: tokens.size(.eventStripe) / 2)
                .fill(color)
                .frame(width: tokens.size(.eventStripe))
            VStack(alignment: .leading, spacing: 0) {
                Text(event.title).font(font.weight(.semibold)).lineLimit(2)
                Text(TimeRangeText.format(event.start, event.end)).font(tokens.font(.caption)).lineLimit(1)
            }
            .foregroundStyle(slot.isPast ? tokens.color(.secondaryText) : tokens.color(.eventText))
            Spacer(minLength: 0)
        }
        .padding(.vertical, tokens.space(.timelineItemPadding) / 2)
        .padding(.trailing, tokens.space(.timelineItemPadding))
        .frame(maxHeight: .infinity, alignment: .top)
        .background(color.opacity(tokens.opacity(.eventFill)),
                    in: RoundedRectangle(cornerRadius: tokens.radius(.timelineItem), style: .continuous))
        .clipShape(RoundedRectangle(cornerRadius: tokens.radius(.timelineItem), style: .continuous))
    }
}

/// A reminder looks like a task: checkbox in the list color on a plate; done/past ones are grey.
struct TimelineReminderBlock: View {
    @Environment(\.tokens) private var tokens
    @Environment(\.icons) private var icons
    let reminder: ReminderItem
    let slot: TimelineSlot
    let font: Font
    var checkboxSize: CGFloat?
    var isCompact = false
    var onToggle: ((ReminderItem) -> Void)?
    var onOpen: ((ReminderItem) -> Void)?

    var body: some View {
        HStack(alignment: .top, spacing: tokens.space(.iconTextGap)) {
            Button { onToggle?(reminder) } label: {
                MarkGlyph(state: reminder.isCompleted ? .marked(.done) : .open,
                          color: slot.isPast ? tokens.color(.past) : Color(hex: reminder.colorHex), size: checkboxSize)
            }
            .buttonStyle(.plain)
            .disabled(onToggle == nil)
            .accessibilityLabel(Text(reminder.isCompleted ? "a11y.uncheck" : "a11y.check"))
            Text(reminder.title)
                .font(font)
                .lineLimit(isCompact ? 1 : 2)
                .foregroundStyle(slot.isPast ? tokens.color(.secondaryText) : tokens.color(.primaryText))
            Spacer(minLength: 0)
            Image(systemName: icons[.reminder]).font(tokens.font(.caption)).foregroundStyle(tokens.color(.secondaryText))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .contentShape(Rectangle())
        .onTapGesture { onOpen?(reminder) }
        .slotPlate(isPast: slot.isPast, isCompact: isCompact)
    }
}

/// A task on the timeline looks exactly like a pool row; done ones turn grey like past events.
struct TimelineTaskBlock<Content: View>: View {
    let item: DayItem
    let isPast: Bool
    var isCompact = false
    @ViewBuilder let content: Content

    var body: some View {
        content
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .slotPlate(isPast: isPast, isCompact: isCompact)
    }
}

extension View {
    /// The pool-row plate; for past items the grey tint of finished events.
    func slotPlate(isPast: Bool, isCompact: Bool = false) -> some View {
        modifier(SlotPlate(isPast: isPast, isCompact: isCompact))
    }
}

private struct SlotPlate: ViewModifier {
    @Environment(\.tokens) private var tokens
    let isPast: Bool
    let isCompact: Bool

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: tokens.radius(isCompact ? .widgetItem : .poolRow), style: .continuous)
        content
            .padding(.vertical, isCompact ? tokens.space(.timelineItemGap) : tokens.space(.rowVertical) / 2)
            .padding(.horizontal, tokens.space(.plateInner) / 2)
            .background(isPast ? tokens.color(.past).opacity(tokens.opacity(.eventFill)) : tokens.color(.plateBackground), in: shape)
            .clipShape(shape)
    }
}

enum TimeRangeText {
    static func format(_ start: Date, _ end: Date) -> String {
        "\(start.formatted(date: .omitted, time: .shortened))–\(end.formatted(date: .omitted, time: .shortened))"
    }
}

extension Color {
    /// Hex of a resolved token color (for components that take hex strings).
    var hexValue: String { UIColor(self).hexString }
}
