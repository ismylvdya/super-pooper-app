import SwiftUI
import WidgetKit

/// A calendar event, drawn as in Apple Calendar, in three colors: the calendar's own for the rounded stripe and the title,
/// a faint tint of it for the plate, and a paler one for the time and the bell (`DesignTokens.eventSecondary`).
struct TimelineEventBlock: View {
    @Environment(\.tokens) private var tokens
    @Environment(\.calendar) private var calendar
    @Environment(\.titleReserve) private var reserve
    @Environment(\.colorScheme) private var colorScheme
    let event: CalendarEvent
    let slot: TimelineSlot
    let font: Font
    /// Line height of `font` (titles fade on their last line).
    let lineHeight: CGFloat

    var body: some View {
        let own = Color(hex: event.colorHex)
        let color = slot.isPast ? tokens.color(.past) : own
        let inset = tokens.space(.eventStripeInset)
        HStack(alignment: .top, spacing: tokens.space(.eventStripeGap)) {
            Capsule()
                .fill(color)
                .frame(width: tokens.size(.eventStripe))
                .padding(.vertical, inset)
                .widgetAccentable()
            TopAlignedContent {
                VStack(alignment: .leading, spacing: 0) {
                    FadingText(text: event.title, font: font, lineHeight: lineHeight, lines: 2,
                               reserve: TitleFade.trailing(corner: reserve, plateInset: tokens.space(.timelineItemPadding),
                                                           gap: tokens.space(.fadeGap)))
                    Text(TimeRangeText.format(event.start, event.end, calendar: calendar)).font(tokens.font(.caption)).lineLimit(1)
                        .opacity(tokens.opacity(.eventTime))
                }
            }
            .padding(.top, inset / 2)
            .foregroundStyle(slot.isPast ? tokens.color(.secondaryText) : own)
            Spacer(minLength: 0)
        }
        .padding(.leading, inset)
        .padding(.trailing, tokens.space(.timelineItemPadding))
        .frame(maxHeight: .infinity, alignment: .top)
        .plate(.timelineItem, fill: tokens.eventFill(color, in: colorScheme), clipsContent: true)
        .opacity(slot.isPast ? tokens.opacity(.past) : 1)
    }
}

extension DesignTokens {
    /// The plate of an event of `color`: as faint as Calendar's in each theme.
    func eventFill(_ color: Color, in scheme: ColorScheme) -> Color {
        color.opacity(opacity(scheme == .dark ? .eventFillDark : .eventFill))
    }

    /// An event's time and bell: its calendar's color, paler than the title.
    func eventSecondary(_ color: Color) -> Color {
        color.opacity(opacity(.eventTime))
    }
}

/// A reminder looks like a task: title on a plate, one line like every row of the timeline; done/past ones are grey. In the app a tap opens it in
/// Reminders and a long press completes it; widgets get the plain plate (no gestures there).
struct TimelineReminderBlock: View {
    @Environment(\.tokens) private var tokens
    @Environment(\.titleReserve) private var reserve
    let reminder: ReminderItem
    let slot: TimelineSlot
    let font: Font
    let lineHeight: CGFloat
    var isCompact = false
    /// An opaque backing under the plate (see `TimelineStyle.backdrop`).
    var backdrop: Color?
    var onToggle: ((ReminderItem) -> Void)?
    var onOpen: ((ReminderItem) -> Void)?

    var body: some View {
        let plate = FadingText(text: reminder.title, font: font, lineHeight: lineHeight, lines: 1,
                               reserve: TitleFade.trailing(corner: reserve, plateInset: tokens.slotPlateInset, gap: tokens.space(.fadeGap)))
            .foregroundStyle(slot.isPast ? tokens.color(.secondaryText) : tokens.color(.primaryText))
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .slotPlate(isPast: slot.isPast, isCompact: isCompact)
        if let onToggle, let onOpen {
            plate
                .background { if let backdrop { tokens.plateShape(.row).fill(backdrop) } }
                .plateLift(.row, for: .contextMenuPreview)
                .onTapGesture { onOpen(reminder) }
                .contextMenu { RegistryMenu(menu: .reminderContext) { _ in onToggle(reminder) } }
        } else {
            plate
        }
    }
}

/// A task on the timeline looks exactly like a pool row; done ones turn grey like past events.
struct TimelineTaskBlock<Content: View>: View {
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
    func slotPlate(isPast: Bool, isCompact: Bool = false, tint: Color? = nil) -> some View {
        modifier(SlotPlate(isPast: isPast, isCompact: isCompact, tint: tint))
    }
}

private struct SlotPlate: ViewModifier {
    @Environment(\.tokens) private var tokens
    let isPast: Bool
    let isCompact: Bool
    let tint: Color?

    func body(content: Content) -> some View {
        content
            .environment(\.plateTrailingInset, tokens.slotPlateInset)
            .padding(.vertical, isCompact ? tokens.space(.compactPlateVertical) : tokens.space(.rowVertical) / 2)
            .padding(.horizontal, tokens.slotPlateInset)
            .plate(.row, fill: isPast ? tokens.color(.past).opacity(tokens.opacity(.eventFill)) : nil, tint: isPast ? nil : tint,
                   clipsContent: true)
            .opacity(isPast ? tokens.opacity(.past) : 1)
    }
}
