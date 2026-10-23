import SwiftUI

/// All-day events of the day as small capsules in their calendar color, above the timeline.
struct AllDayStrip: View {
    @Environment(\.tokens) private var tokens
    let events: [CalendarEvent]
    var font: Font?
    var onTap: ((CalendarEvent) -> Void)?

    var body: some View {
        ChipFlow(spacing: tokens.space(.chipGap)) {
            ForEach(events) { event in
                Button { onTap?(event) } label: {
                    HStack(spacing: 4) {
                        Circle().fill(Color(hex: event.colorHex)).frame(width: tokens.size(.problemDot), height: tokens.size(.problemDot))
                        Text(event.title).font(font ?? tokens.font(.chip)).lineLimit(1)
                    }
                    .foregroundStyle(tokens.color(.eventText))
                    .padding(.horizontal, tokens.space(.chipHorizontal))
                    .padding(.vertical, tokens.space(.chipVertical))
                    .background(Color(hex: event.colorHex).opacity(tokens.opacity(.eventFill)), in: Capsule())
                }
                .buttonStyle(.plain)
                .disabled(onTap == nil)
            }
        }
    }
}
