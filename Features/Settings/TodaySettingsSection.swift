import SwiftUI

/// Where the pool and the timeline sit on Today and in the widget (each has its own), with live schematic previews.
struct TodaySettingsSection: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        arrangementSection(header: "settings.today", hint: "settings.today.hint", info: "info.settings.today.arrangement",
                           keyPath: \.arrangement)
        arrangementSection(header: "settings.widget", hint: "settings.widget.hint", info: "info.settings.widget.arrangement",
                           keyPath: \.widgetArrangement)
    }

    private func arrangementSection(header: LocalizedStringKey, hint: LocalizedStringKey, info: LocalizedStringKey,
                                    keyPath: WritableKeyPath<AppSettings.Today, AppSettings.TodayArrangement>) -> some View {
        let current = model.settings.today[keyPath: keyPath]
        return PlateSection(header: header, hint: hint) {
            ArrangementPreview(arrangement: current)
            PlateRow(icon: .timelineLayout, title: "settings.today.arrangement", info: info) {}
            Picker("settings.today.arrangement", selection: Binding(
                get: { current },
                set: { value in
                    Haptics.play(.light)
                    model.updateSettings { $0.today[keyPath: keyPath] = value }
                }
            )) {
                Text("settings.today.stacked").tag(AppSettings.TodayArrangement.stacked)
                Text("settings.today.sideBySide").tag(AppSettings.TodayArrangement.sideBySide)
            }
            .pickerStyle(.segmented)
        }
    }
}

/// A small drawing of the arrangement: the pool plate and the timeline with an hour grid.
struct ArrangementPreview: View {
    @Environment(AppModel.self) private var model
    @Environment(\.tokens) private var tokens
    let arrangement: AppSettings.TodayArrangement

    var body: some View {
        ScreenLayoutView(layout: model.config.todayLayout(for: arrangement)) { id in
            if id == "pool" { pool } else { timeline }
        }
        .frame(height: 120)
        .padding(tokens.space(.chipGap))
        .background(tokens.color(.screenBackground), in: RoundedRectangle(cornerRadius: tokens.radius(.timelineItem), style: .continuous))
        .animation(tokens.animation, value: arrangement)
        .accessibilityHidden(true)
    }

    private var pool: some View {
        VStack(spacing: 4) {
            ForEach(0..<3, id: \.self) { _ in
                RoundedRectangle(cornerRadius: 4, style: .continuous).fill(tokens.color(.plateBackground)).frame(height: 16)
            }
            if arrangement == .sideBySide { Spacer(minLength: 0) }
        }
        .frame(idealWidth: 80)
    }

    private var timeline: some View {
        VStack(spacing: 0) {
            ForEach(0..<6, id: \.self) { _ in
                Rectangle().fill(tokens.color(.timelineGrid)).frame(height: 0.5)
                Spacer(minLength: 0)
            }
        }
        .overlay(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 4, style: .continuous).fill(tokens.color(.accent).opacity(0.35))
                .frame(height: 22).padding(.top, 30)
        }
    }
}
