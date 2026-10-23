import SwiftUI

/// The Clock tab: the time in the chosen zone (Moscow by default), large, with the date and the
/// zone's offset from here. The same line is on the Lock Screen widget.
struct ClockScreen: View {
    @Environment(AppModel.self) private var model
    @Environment(\.tokens) private var tokens

    var body: some View {
        let zone = TimeZone(identifier: model.settings.clock.timeZone) ?? .current
        TimelineView(.periodic(from: .now, by: 1)) { context in
            VStack(spacing: tokens.space(.groupGap)) {
                Text(verbatim: zoneName(zone))
                    .font(tokens.font(.clockCaption))
                    .foregroundStyle(tokens.color(.secondaryText))
                Text(verbatim: ClockLine.time(context.date, timeZone: zone))
                    .font(tokens.font(.clockTime))
                    .monospacedDigit()
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)
                    .accessibilityIdentifier("clock.time")
                Text(verbatim: date(context.date, zone: zone))
                    .font(tokens.font(.clockCaption))
                Text(verbatim: offset(zone, at: context.date))
                    .font(tokens.font(.hint))
                    .foregroundStyle(tokens.color(.secondaryText))
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(.horizontal, tokens.space(.screenHorizontal))
        }
        .background(tokens.color(.screenBackground))
        .navigationTitle(Text("tab.clock"))
        .navigationBarTitleDisplayMode(.inline)
    }

    private func zoneName(_ zone: TimeZone) -> String {
        zone.localizedName(for: .generic, locale: .current) ?? zone.identifier
    }

    private func date(_ date: Date, zone: TimeZone) -> String {
        var style = Date.FormatStyle(date: .complete, time: .omitted)
        style.timeZone = zone
        return date.formatted(style)
    }

    /// "+1 h from here", "same time as here".
    private func offset(_ zone: TimeZone, at date: Date) -> String {
        let seconds = zone.secondsFromGMT(for: date) - TimeZone.current.secondsFromGMT(for: date)
        guard seconds != 0 else { return L10n.string("clock.sameTime") }
        let hours = Double(seconds) / 3600
        let text = hours.rounded() == hours ? String(format: "%+d", Int(hours)) : String(format: "%+.1f", hours)
        return L10n.format("clock.offset", text)
    }
}

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
                TextField("settings.clock.prefix.placeholder", text: $prefix)
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
