import SwiftUI

/// Settings of the clock: the zone and the text before the time on the Lock Screen widget, with a preview.
struct ClockSettingsSection: View {
    @Environment(AppModel.self) private var model
    @State private var prefix = ""

    var body: some View {
        let zone = TimeZone(identifier: model.settings.clock.timeZone) ?? .current
        PlateSection(header: "settings.clock", info: "info.settings.clock",
                     hint: LocalizedStringKey(L10n.format("settings.clock.preview",
                                                          ClockLine.text(prefix: prefix, date: model.clock.now, timeZone: zone)))) {
            PlateRow(icon: .clockSettings, title: "settings.clock.zone") {
                Picker("settings.clock.zone", selection: Binding(
                    get: { model.settings.clock.timeZone },
                    set: { value in model.updateSettings { $0.clock.timeZone = value } }
                )) {
                    ForEach(zones, id: \.self) { Text(verbatim: $0).tag($0) }
                }
                .labelsHidden()
            }
            PlateRow(icon: .title, title: "settings.clock.prefix") {
                TextField("settings.clock.prefix.placeholder", text: Binding(get: { prefix.withVisibleTrailingSpaces },
                                                                              set: { prefix = $0.withOrdinarySpaces }))
                    .multilineTextAlignment(.trailing)
                    .autocorrectionDisabled()
                    .onSubmit { model.updateSettings { $0.clock.prefix = prefix } }
                    .onChange(of: prefix) { _, value in model.updateSettings { $0.clock.prefix = value } }
            }
        }
        .onAppear { prefix = model.settings.clock.prefix }
    }

    /// The configured zone first, then all known zones.
    private var zones: [String] {
        let current = model.settings.clock.timeZone
        return [current] + TimeZone.knownTimeZoneIdentifiers.filter { $0 != current }
    }
}
