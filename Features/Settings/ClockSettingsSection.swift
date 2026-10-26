import SwiftUI

/// Settings of the clock: the zone and the text before the time on the Lock Screen widget, with a preview.
struct ClockSettingsSection: View {
    @Environment(AppModel.self) private var model
    @State private var prefix = ""

    var body: some View {
        let zone = TimeZone(identifier: model.settings.clock.timeZone) ?? .current
        PlateSection(header: "settings.clock", info: "info.settings.clock",
                     hint: Text(verbatim: L10n.format("settings.clock.preview",
                                                      ClockLine.text(prefix: prefix, date: model.clock.now, timeZone: zone)))) {
            PlateRow(icon: .clockSettings, title: "settings.clock.zone") {
                // The row shows the offset alone; the list names the city next to it.
                Menu {
                    Picker("settings.clock.zone", selection: Binding(
                        get: { model.settings.clock.timeZone },
                        set: { value in model.updateSettings { $0.clock.timeZone = value } }
                    )) {
                        ForEach(zones, id: \.self) { identifier in
                            Text(verbatim: zoneItem(identifier)).tag(identifier)
                        }
                    }
                } label: {
                    Text(verbatim: TimeZoneName.offset(zone, at: model.clock.now))
                }
                .accessibilityIdentifier("settings.clock.zone")
            }
            PlateRow(icon: .title, title: "settings.clock.prefix") {
                TrailingSpaceTextField(placeholder: "settings.clock.prefix.placeholder", text: $prefix)
                    .autocorrectionDisabled()
                    .onSubmit { model.updateSettings { $0.clock.prefix = prefix } }
                    .onChange(of: prefix) { _, value in model.updateSettings { $0.clock.prefix = value } }
            }
        }
        .onAppear { prefix = model.settings.clock.prefix }
    }

    private func zoneItem(_ identifier: String) -> String {
        let zone = TimeZone(identifier: identifier) ?? .current
        return L10n.format("clock.zoneItem", TimeZoneName.offset(zone, at: model.clock.now), TimeZoneName.city(identifier))
    }

    /// The configured zone first, then all known zones.
    private var zones: [String] {
        let current = model.settings.clock.timeZone
        return [current] + TimeZone.knownTimeZoneIdentifiers.filter { $0 != current }
    }
}
