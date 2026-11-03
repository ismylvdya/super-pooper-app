import SwiftUI

/// Every zone the system knows, searchable; the first row, None, goes back to the phone's clock. Picking a row closes
/// the picker (the sheet it is in, or the page it was pushed as).
struct TimeZonePicker: View {
    @Environment(\.tokens) private var tokens
    @Environment(\.icons) private var icons
    @Environment(\.dismiss) private var dismiss
    let selected: String?
    let onPick: (String?) -> Void
    @State private var query = ""

    var body: some View {
        List {
            row(Self.title(of: nil), isSelected: selected == nil) { pick(nil) }
            ForEach(TimeZone.knownTimeZoneIdentifiers.filter { SearchMatcher.matches(Self.name($0), query) }, id: \.self) { id in
                row(Self.name(id), isSelected: selected == id) { pick(id) }
            }
        }
        .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always))
        .navigationTitle(Text("taskPage.timeZone"))
        .navigationBarTitleDisplayMode(.inline)
    }

    /// A zone as a row says it; None for no zone.
    static func title(of zone: String?) -> String {
        zone.map(name) ?? L10n.string("taskPage.timeZone.none")
    }

    static func name(_ identifier: String) -> String {
        identifier.replacingOccurrences(of: "_", with: " ")
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
                if isSelected { Image(systemName: icons[.selected]).foregroundStyle(tokens.color(.accent)) }
            }
        }
        .accessibilityIdentifier("timeZone.\(title)")
    }
}
