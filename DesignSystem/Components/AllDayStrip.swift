import SwiftUI
import WidgetKit

/// All-day events of the day, one full-width bar each in its calendar color, above the timeline.
/// Long titles fade out; in the app a tap opens Calendar and a long press offers deleting the event.
struct AllDayStrip: View {
    @Environment(\.tokens) private var tokens
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.icons) private var icons
    let events: [CalendarEvent]
    var font: Font?
    let lineHeight: CGFloat
    var onTap: ((CalendarEvent) -> Void)?
    var onDelete: ((CalendarEvent) -> Void)?

    var body: some View {
        VStack(spacing: tokens.space(.chipGap)) {
            ForEach(events) { event in
                if let onTap {
                    Button { onTap(event) } label: { bar(event) }
                        .buttonStyle(.plain)
                        .contentShape(.contextMenuPreview, Capsule())
                        .contextMenu {
                            if let onDelete { RegistryMenu(menu: .eventContext) { _ in onDelete(event) } }
                        }
                } else {
                    bar(event)
                }
            }
        }
        .padding(.leading, Self.leadingInset(lineHeight: lineHeight, tokens: tokens))
    }

    /// Widgets have no buttons: the bar is plain there.
    private func bar(_ event: CalendarEvent) -> some View {
        // The round icon stands as far from the capsule's left end as from its top and bottom: concentric with the end.
        let inset = ChipCapsule.standard.verticalPadding(tokens)
        return HStack(spacing: tokens.space(.dotTextGap)) {
            Image(systemName: icons[.allDayEvent])
                .resizable()
                .symbolRenderingMode(.palette)
                .foregroundStyle(tokens.color(.eventIconGlyph), Color(hex: event.colorHex))
                .frame(width: lineHeight, height: lineHeight)
                .widgetAccentable()
            FadingText(text: event.title, font: font ?? tokens.font(.chip), lineHeight: lineHeight)
        }
        .foregroundStyle(tokens.eventText(Color(hex: event.colorHex), in: colorScheme))
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.leading, inset)
        .padding(.trailing, ChipCapsule.standard.horizontalPadding(tokens))
        .padding(.vertical, inset)
        .background(tokens.eventFill(Color(hex: event.colorHex), in: colorScheme), in: Capsule())
    }
}

extension AllDayStrip {
    /// The height the strip takes with `count` bars of text `lineHeight` high: what a layout around it leaves for it.
    static func height(count: Int, lineHeight: CGFloat, tokens: DesignTokens) -> CGFloat {
        guard count > 0 else { return 0 }
        let bar = lineHeight + ChipCapsule.standard.verticalPadding(tokens) * 2
        return CGFloat(count) * bar + CGFloat(count - 1) * tokens.space(.chipGap)
    }

    /// How far the bars start from the hour column's left edge: their round icons stand over the middle of the hour numbers.
    /// With text so large that this would take them past the column's edge, they stay at the edge.
    static func leadingInset(lineHeight: CGFloat, tokens: DesignTokens) -> CGFloat {
        max(tokens.hourDigitsCenter - ChipCapsule.standard.verticalPadding(tokens) - lineHeight / 2, 0)
    }
}
