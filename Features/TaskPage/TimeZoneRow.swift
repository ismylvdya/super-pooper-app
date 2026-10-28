import SwiftUI

/// The zone an item's times are kept in: the phone's time (wall-clock, the default) or a zone picked from the list —
/// then 09:00 means 09:00 there, wherever the phone is (`ZonedTimes`). Shown only for an item with a time.
struct TimeZoneRow: View {
    @Environment(\.tokens) private var tokens
    let editor: TaskEditor
    @State private var isPicking = false

    var body: some View {
        let task = editor.task
        if task.due?.time != nil || !task.reminderTimes.isEmpty {
            PlateRow(icon: .timeZone, title: "taskPage.timeZone", info: "info.taskPage.timeZone") {
                Button { isPicking = true } label: {
                    Text(task.timeZone.map(Self.name) ?? L10n.string("taskPage.timeZone.phone"))
                        .foregroundStyle(tokens.color(.secondaryText))
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("taskPage.timeZone")
            }
            .sheet(isPresented: $isPicking) {
                TimeZonePicker(selected: task.timeZone) { zone in
                    editor.apply([.timeZone(zone)])
                    isPicking = false
                }
            }
        }
    }

    static func name(_ identifier: String) -> String {
        identifier.replacingOccurrences(of: "_", with: " ")
    }
}

/// Every zone the system knows, searchable; the first row goes back to the phone's time.
private struct TimeZonePicker: View {
    @Environment(\.tokens) private var tokens
    @Environment(\.icons) private var icons
    let selected: String?
    let onPick: (String?) -> Void
    @State private var query = ""

    var body: some View {
        NavigationStack {
            List {
                row(L10n.string("taskPage.timeZone.phone"), isSelected: selected == nil) { onPick(nil) }
                ForEach(TimeZone.knownTimeZoneIdentifiers.filter { SearchMatcher.matches(TimeZoneRow.name($0), query) }, id: \.self) { id in
                    row(TimeZoneRow.name(id), isSelected: selected == id) { onPick(id) }
                }
            }
            .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always))
            .navigationTitle(Text("taskPage.timeZone"))
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private func row(_ title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                Text(verbatim: title).foregroundStyle(tokens.color(.primaryText))
                Spacer()
                if isSelected { Image(systemName: icons[.selected]).foregroundStyle(tokens.color(.accent)) }
            }
        }
    }
}
