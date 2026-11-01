import SwiftUI

/// Settings of the clock: the zone and the text before the time on the Lock Screen widget, with a preview.
struct ClockSettingsSection: View {
    @Environment(AppModel.self) private var model
    @Environment(\.icons) private var icons
    @State private var prefix = ""

    var body: some View {
        let zone = TimeZone(identifier: model.settings.clock.timeZone) ?? .current
        PlateSection(header: "settings.clock", info: "info.settings.clock",
                     hint: Text(verbatim: L10n.format("settings.clock.preview",
                                                      ClockLine.text(prefix: prefix, date: model.clock.now, timeZone: zone)))) {
            PlateRow(icon: .clockSettings, title: "settings.clock.zone") {
                // The row shows the offset alone; in the list each zone is its city, with its offset as the line under it
                // and a check on the chosen one (a picker's item has room for one line only).
                Menu {
                    ForEach(zones, id: \.self) { identifier in
                        Button {
                            model.updateSettings { $0.clock.timeZone = identifier }
                        } label: {
                            Text(verbatim: TimeZoneName.city(identifier))
                            Text(verbatim: offset(identifier))
                            if identifier == model.settings.clock.timeZone { Image(systemName: icons[.selected]) }
                        }
                    }
                } label: {
                    Text(verbatim: TimeZoneName.offset(zone, at: model.clock.now))
                }
                .accessibilityIdentifier("settings.clock.zone")
            }
            PlateRow(icon: .title, title: "settings.clock.prefix") {
                TrailingSpaceTextField(placeholder: "settings.clock.prefix.placeholder", text: $prefix) {
                    model.updateSettings { $0.clock.prefix = prefix }
                }
                    .onChange(of: prefix) { _, value in model.updateSettings { $0.clock.prefix = value } }
            }
        }
        .onAppear { prefix = model.settings.clock.prefix }
    }

    private func offset(_ identifier: String) -> String {
        TimeZoneName.offset(TimeZone(identifier: identifier) ?? .current, at: model.clock.now)
    }

    /// The configured zone first, then all known zones.
    private var zones: [String] {
        let current = model.settings.clock.timeZone
        return [current] + TimeZone.knownTimeZoneIdentifiers.filter { $0 != current }
    }
}
