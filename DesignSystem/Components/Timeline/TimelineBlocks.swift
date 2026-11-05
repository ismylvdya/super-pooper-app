import SwiftUI
import WidgetKit

/// A calendar event, drawn as in Apple Calendar: the calendar's own color for the rounded stripe, a faint tint of it for the
/// plate, a deep tone for the title and a middle one for the time and the bell (`DesignTokens`).
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
                        .foregroundStyle(slot.isPast ? tokens.color(.secondaryText) : tokens.eventTitle(own, in: colorScheme))
                    Text(TimeRangeText.format(event.start, event.end, calendar: calendar))
                        .lineLimit(1)
                        .font(tokens.font(.caption))
                        .foregroundStyle(slot.isPast ? tokens.color(.secondaryText) : tokens.eventSecondary(own, in: colorScheme))
                }
            }
            .padding(.top, inset / 2)
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

    /// An event's title: its calendar's color, deep in the light theme, nearly itself in the dark one.
    func eventTitle(_ color: Color, in scheme: ColorScheme) -> Color {
        scheme == .dark ? color.opacity(opacity(.eventTitleDark)) : color.mix(with: .black, by: opacity(.eventTitleLightMix))
    }

    /// An event's time and bell: a step toward the color itself from the title.
    func eventSecondary(_ color: Color, in scheme: ColorScheme) -> Color {
        scheme == .dark ? color.opacity(opacity(.eventTimeDark)) : color.mix(with: .black, by: opacity(.eventTimeLightMix))
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
    /// The height of a one-line plate: its ring and title stand in the middle of it.
    var oneLineHeight: CGFloat = 0
    /// An opaque backing under the plate (see `TimelineStyle.backdrop`).
    var backdrop: Color?
    var onToggle: ((ReminderItem) -> Void)?
    var onOpen: ((ReminderItem) -> Void)?

    var body: some View {
        let plate = HStack(alignment: .top, spacing: tokens.space(.reminderRingGap)) {
            ring
            FadingText(text: reminder.title, font: font, lineHeight: lineHeight, lines: 1,
                       reserve: TitleFade.trailing(corner: reserve, plateInset: tokens.slotPlateInset, gap: tokens.space(.fadeGap)))
                .foregroundStyle(slot.isPast ? tokens.color(.secondaryText) : tokens.color(.primaryText))
        }
        .padding(.top, centering)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .slotPlate(isPast: slot.isPast, isCompact: isCompact, corners: .timelineItem)
        if let onToggle, let onOpen {
            plate
                .background { if let backdrop { tokens.plateShape(.timelineItem).fill(backdrop) } }
                .plateLift(.timelineItem, for: .contextMenuPreview)
                .onTapGesture { onOpen(reminder) }
                .contextMenu { RegistryMenu(menu: .reminderContext) { _ in onToggle(reminder) } }
        } else {
            plate
        }
    }
}

private extension TimelineReminderBlock {
    /// How far the line stands below the plate's inset, for its middle to be the one-line plate's.
    var centering: CGFloat {
        let inset = isCompact ? tokens.space(.compactPlateVertical) : tokens.space(.rowVertical) / 2
        return max(oneLineHeight / 2 - inset - lineHeight / 2, 0)
    }

    /// An open reminder as Apple's Calendar draws it: a ring in its list's color, standing in the title's line.
    var ring: some View {
        Circle()
            .strokeBorder(slot.isPast ? tokens.color(.secondaryText) : Color(hex: reminder.colorHex), lineWidth: tokens.size(.reminderRingStroke))
            .frame(width: tokens.size(.reminderRing), height: tokens.size(.reminderRing))
            .frame(height: lineHeight)
            .widgetAccentable()
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
    func slotPlate(isPast: Bool, isCompact: Bool = false, tint: Color? = nil, corners: PlateCorners = .row) -> some View {
        modifier(SlotPlate(isPast: isPast, isCompact: isCompact, tint: tint, corners: corners))
    }
}

private struct SlotPlate: ViewModifier {
    @Environment(\.tokens) private var tokens
    let isPast: Bool
    let isCompact: Bool
    let tint: Color?
    let corners: PlateCorners

    func body(content: Content) -> some View {
        content
            .environment(\.plateTrailingInset, tokens.slotPlateInset)
            .padding(.vertical, isCompact ? tokens.space(.compactPlateVertical) : tokens.space(.rowVertical) / 2)
            .padding(.horizontal, tokens.slotPlateInset)
            .plate(corners, fill: isPast ? tokens.color(.past).opacity(tokens.opacity(.eventFill)) : nil, tint: isPast ? nil : tint,
                   clipsContent: true)
            .opacity(isPast ? tokens.opacity(.past) : 1)
    }
}
