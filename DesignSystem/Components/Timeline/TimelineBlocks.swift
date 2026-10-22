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

/// A reminder: read-only, with the list's color dot.
struct TimelineReminderBlock: View {
    @Environment(\.tokens) private var tokens
    @Environment(\.icons) private var icons
    let reminder: ReminderItem
    let slot: TimelineSlot
    let font: Font

    var body: some View {
        HStack(spacing: tokens.space(.timelineItemPadding)) {
            SourceDot(hex: slot.isPast ? tokens.color(.past).hexValue : reminder.colorHex)
            Image(systemName: icons[.reminder]).font(tokens.font(.caption))
            Text(reminder.title).font(font).lineLimit(1)
            Spacer(minLength: 0)
            Text(reminder.due.formatted(date: .omitted, time: .shortened)).font(tokens.font(.caption))
        }
        .foregroundStyle(slot.isPast ? tokens.color(.secondaryText) : tokens.color(.primaryText))
        .padding(.horizontal, tokens.space(.timelineItemPadding))
        .frame(maxHeight: .infinity, alignment: .top)
        .padding(.top, tokens.space(.timelineItemPadding) / 2)
        .background(tokens.color(.chipBackground), in: RoundedRectangle(cornerRadius: tokens.radius(.timelineItem), style: .continuous))
    }
}

/// A task on the timeline: the same row as in the pool on a light tint of its color.
struct TimelineTaskBlock<Content: View>: View {
    @Environment(\.tokens) private var tokens
    let item: DayItem
    let isPast: Bool
    @ViewBuilder let content: Content

    var body: some View {
        content
            .padding(.horizontal, tokens.space(.timelineItemPadding))
            .padding(.vertical, tokens.space(.timelineItemPadding) / 2)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(tint.opacity(tokens.opacity(.taskFill)),
                        in: RoundedRectangle(cornerRadius: tokens.radius(.timelineItem), style: .continuous))
            .clipShape(RoundedRectangle(cornerRadius: tokens.radius(.timelineItem), style: .continuous))
    }

    private var tint: Color {
        isPast ? tokens.color(.past) : tokens.color(item.isHabit ? .habit : .task)
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
