import SwiftUI

/// The most system-like event chooser: a search field and the next days' events of the anchor
/// calendars, each with its calendar's colored dot.
struct EventPickerScreen: View {
    @Environment(AppModel.self) private var model
    @Environment(\.dismiss) private var dismiss
    @Environment(\.tokens) private var tokens
    let onPick: (CalendarEvent) -> Void
    @State private var query = ""

    var body: some View {
        let days = model.pickableEvents(matching: query)
        NavigationStack {
            List {
                ForEach(days, id: \.day) { group in
                    Section {
                        ForEach(group.events) { event in
                            Button {
                                onPick(event)
                                dismiss()
                            } label: { row(event) }
                        }
                    } header: {
                        Text(DateText.format(group.day, .dateTime.weekday(.wide).day().month(.wide), calendar: model.calendar))
                    }
                }
            }
            .overlay {
                if days.isEmpty {
                    Text(model.settings.sources.anchorCalendarIDs.isEmpty ? "picker.event.noCalendars" : "picker.event.empty")
                        .multilineTextAlignment(.center)
                        .foregroundStyle(tokens.color(.secondaryText))
                        .padding()
                }
            }
            .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always), prompt: Text("picker.event.search"))
            .navigationTitle(Text("picker.event.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("common.cancel") { dismiss() } } }
        }
    }

    private func row(_ event: CalendarEvent) -> some View {
        HStack(spacing: tokens.space(.iconTextGap)) {
            SourceDot(hex: event.colorHex)
            TitleDetailLabel(detail: Text(event.isAllDay ? L10n.string("picker.event.allDay") : TimeRangeText.format(event.start, event.end, calendar: model.calendar))) {
                Text(event.title).foregroundStyle(tokens.color(.primaryText))
            }
        }
    }
}
