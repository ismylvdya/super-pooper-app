import SwiftUI
import WidgetKit

/// All-day events of the day, one full-width bar each in its calendar color, above the timeline.
/// Long titles fade out; in the app a tap opens Calendar and a long press offers deleting the event.
struct AllDayStrip: View {
    @Environment(\.tokens) private var tokens
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
    }

    /// Widgets have no buttons: the bar is plain there.
    private func bar(_ event: CalendarEvent) -> some View {
        HStack(spacing: tokens.space(.dotTextGap)) {
            Circle().fill(Color(hex: event.colorHex)).frame(width: tokens.size(.eventDot), height: tokens.size(.eventDot))
                .widgetAccentable()
            FadingText(text: event.title, font: font ?? tokens.font(.chip), lineHeight: lineHeight)
        }
        .foregroundStyle(tokens.color(.eventText))
        .frame(maxWidth: .infinity, alignment: .leading)
        .chipCapsule(Color(hex: event.colorHex).opacity(tokens.opacity(.eventFill)))
    }
}

extension AllDayStrip {
    /// The height the strip takes with `count` bars of text `lineHeight` high: what a layout around it leaves for it.
    static func height(count: Int, lineHeight: CGFloat, tokens: DesignTokens) -> CGFloat {
        guard count > 0 else { return 0 }
        let bar = max(lineHeight, tokens.size(.eventDot)) + ChipCapsule.standard.verticalPadding(tokens) * 2
        return CGFloat(count) * bar + CGFloat(count - 1) * tokens.space(.chipGap)
    }
}
