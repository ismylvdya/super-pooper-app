import SwiftUI

/// All-day events of the day, one full-width bar each in its calendar color, above the timeline.
/// Long titles fade out; in the app a tap opens Calendar and a long press offers deleting the event.
struct AllDayStrip: View {
    @Environment(\.tokens) private var tokens
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
                            if let onDelete {
                                Button(role: .destructive) { onDelete(event) } label: {
                                    Label(LocalizedStringKey("action.deleteEvent"), systemImage: icons[.delete])
                                }
                            }
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
            Circle().fill(Color(hex: event.colorHex)).frame(width: tokens.size(.problemDot), height: tokens.size(.problemDot))
            FadingText(text: event.title, font: font ?? tokens.font(.chip), lineHeight: lineHeight)
        }
        .foregroundStyle(tokens.color(.eventText))
        .padding(.horizontal, tokens.space(.chipHorizontal))
        .padding(.vertical, tokens.space(.chipVertical))
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(hex: event.colorHex).opacity(tokens.opacity(.eventFill)), in: Capsule())
    }
}
