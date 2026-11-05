import SwiftUI

/// The zones by their offset from UTC, each row with its best known cities ("+7 UTC (Bangkok, Ho Chi Minh)"); a search goes
/// through every zone the system knows, city by city. The first row, None, goes back to the phone's clock. Picking a row closes
/// the picker (the sheet it is in, or the page it was pushed as).
struct TimeZonePicker: View {
    @Environment(\.tokens) private var tokens
    @Environment(\.icons) private var icons
    @Environment(\.dismiss) private var dismiss
    @Environment(AppModel.self) private var model
    let selected: String?
    let onPick: (String?) -> Void
    @State private var query = ""

    var body: some View {
        List {
            row(Self.title(of: nil, at: now), isSelected: selected == nil) { pick(nil) }
            if query.isEmpty {
                ForEach(TimeZoneName.groups(rules: model.config.rules.timeZones, at: now), id: \.identifiers) { group in
                    row(TimeZoneName.title(of: group, cities: model.config.rules.timeZones.citiesInRow),
                        isSelected: selected.map(group.identifiers.contains) == true) { pick(group.identifiers[0]) }
                }
            } else {
                ForEach(found, id: \.self) { id in
                    row(Self.title(of: id, at: now), isSelected: selected == id) { pick(id) }
                }
            }
        }
        .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always))
        .navigationTitle(Text("taskPage.timeZone"))
        .navigationBarTitleDisplayMode(.inline)
    }

    private var now: Date { model.clock.now }

    private var found: [String] {
        let matching = TimeZone.knownTimeZoneIdentifiers.filter { SearchMatcher.matches($0.replacingOccurrences(of: "_", with: " "), query) }
        return TimeZoneGroups.zones(matching, priority: model.config.rules.timeZones.priority, at: now)
    }

    /// A zone as a row says it: its offset now and its city; None for no zone.
    static func title(of zone: String?, at date: Date) -> String {
        zone.map { TimeZoneName.title(of: $0, at: date) } ?? L10n.string("taskPage.timeZone.none")
    }

    private func pick(_ zone: String?) {
        onPick(zone)
        dismiss()
    }

    private func row(_ title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                Text(verbatim: title).foregroundStyle(tokens.color(.primaryText))
                Spacer()
                if isSelected { Image(systemName: icons[.selected]).foregroundStyle(tokens.color(.accentCheckmark)) }
            }
        }
        .accessibilityIdentifier("timeZone.\(title)")
    }
}
