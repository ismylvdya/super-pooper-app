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
        NavigationStack {
            List {
                ForEach(days, id: \.self) { day in
                    Section {
                        ForEach(events(on: day)) { event in
                            Button {
                                onPick(event)
                                dismiss()
                            } label: { row(event) }
                        }
                    } header: {
                        Text(day.startDate(in: model.calendar).formatted(.dateTime.weekday(.wide).day().month(.wide)))
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
            TitleDetailLabel(detail: Text(event.isAllDay ? L10n.string("picker.event.allDay") : TimeRangeText.format(event.start, event.end))) {
                Text(event.title).foregroundStyle(tokens.color(.primaryText))
            }
        }
    }

    private var candidates: [CalendarEvent] {
        let context = model.context()
        let end = context.today.adding(days: model.config.rules.eventLinks.pickerDaysAhead).startDate(in: model.calendar)
        return model.events.filter { $0.end > context.now && $0.start < end }
            .filter { query.isEmpty || $0.title.localizedCaseInsensitiveContains(query) }
    }

    private var days: [LocalDate] {
        Array(Set(candidates.map { LocalDate($0.start, in: model.calendar) })).sorted()
    }

    private func events(on day: LocalDate) -> [CalendarEvent] {
        candidates.filter { LocalDate($0.start, in: model.calendar) == day }
    }
}
