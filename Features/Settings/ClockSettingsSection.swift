import SwiftUI

/// Settings of the clock: the zone and the text before the time on the Lock Screen widget, with a preview.
struct ClockSettingsSection: View {
    @Environment(AppModel.self) private var model
    @Environment(\.icons) private var icons
    @Environment(\.tokens) private var tokens
    @State private var prefix = ""

    var body: some View {
        let zone = TimeZone(identifier: model.settings.clock.timeZone) ?? .current
        PlateSection(header: "settings.clock", info: "info.settings.clock",
                     hint: Text(verbatim: L10n.format("settings.clock.preview",
                                                      ClockLine.text(prefix: prefix, date: model.clock.now, timeZone: zone)))) {
            PlateRow(icon: .clockSettings, title: "settings.clock.zone") {
                // The row shows the offset alone; the list the rows every zone list has, with a check on the chosen one.
                Menu {
                    ForEach(groups, id: \.identifiers) { group in
                        Button {
                            model.updateSettings { $0.clock.timeZone = group.identifiers[0] }
                        } label: {
                            Text(verbatim: TimeZoneName.title(of: group, cities: model.config.rules.timeZones.citiesInRow))
                            if group.identifiers.contains(model.settings.clock.timeZone) { Image(systemName: icons[.selected]) }
                        }
                    }
                } label: {
                    Text(verbatim: TimeZoneName.offset(zone, at: model.clock.now))
                }
                .accessibilityIdentifier("settings.clock.zone")
            }
            PlateRow(icon: .title, title: "settings.clock.prefix") {
                // The quotes show where the text starts and ends, spaces included; they are outside the field.
                HStack(spacing: 0) {
                    Text(verbatim: "“")
                    TrailingSpaceTextField(placeholder: "settings.clock.prefix.placeholder", text: $prefix) {
                        model.updateSettings { $0.clock.prefix = prefix }
                    }
                    .onChange(of: prefix) { _, value in model.updateSettings { $0.clock.prefix = value } }
                    .fixedSize()
                    Text(verbatim: "”")
                }
                .foregroundStyle(tokens.color(.secondaryText))
            }
        }
        .onAppear { prefix = model.settings.clock.prefix }
    }

    private var groups: [TimeZoneGroup] {
        TimeZoneName.groups(rules: model.config.rules.timeZones, at: model.clock.now)
    }
}
