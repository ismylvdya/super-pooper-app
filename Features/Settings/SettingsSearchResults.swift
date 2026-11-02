import SwiftUI

/// What the search in Settings found: a plate per section under its own title, a row per setting that opens the page it
/// is on (one on Settings itself closes the search to show it there).
struct SettingsSearchResults: View {
    @Environment(\.tokens) private var tokens
    let results: [SettingsSearchIndex.Result]
    let onShowHere: () -> Void

    var body: some View {
        if results.isEmpty {
            Text("settings.search.empty").secondaryText()
                .frame(maxWidth: .infinity)
                .accessibilityIdentifier("settings.search.empty")
        }
        ForEach(results, id: \.self) { result in
            PlateSection(header: Text(verbatim: result.title)) {
                if result.rows.isEmpty {
                    row(Text("settings.search.open"), route: result.route)
                }
                ForEach(result.rows, id: \.self) { title in row(Text(verbatim: title), route: result.route) }
            }
        }
    }

    @ViewBuilder private func row(_ title: Text, route: Route?) -> some View {
        if let route {
            NavigationLink(value: route) { PlateRow(icon: nil, title: title) { DisclosureAccessory(value: nil) } }
                .buttonStyle(.plain)
                .accessibilityIdentifier("settings.search.result")
        } else {
            Button(action: onShowHere) { PlateRow(icon: nil, title: title) { DisclosureAccessory(value: nil) } }
                .buttonStyle(.plain)
                .accessibilityIdentifier("settings.search.result")
        }
    }
}
