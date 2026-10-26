import SwiftUI

/// Where the pool and the timeline sit on Today upright, on Today in landscape and in the widget (each has its own),
/// with live schematic previews.
struct TodaySettingsSection: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        arrangementSection(header: "settings.today", hint: "settings.today.hint", info: "info.settings.today.arrangement",
                           keyPath: \.arrangement, options: AppSettings.TodayArrangement.allCases)
        arrangementSection(header: "settings.landscape", hint: "settings.landscape.hint", info: "info.settings.today.arrangement",
                           keyPath: \.landscapeArrangement, options: AppSettings.TodayArrangement.allCases)
        // The widget has no pages.
        arrangementSection(header: "settings.widget", hint: "settings.widget.hint", info: "info.settings.widget.arrangement",
                           keyPath: \.widgetArrangement, options: [.stacked, .sideBySide])
    }

    private func arrangementSection(header: LocalizedStringKey, hint: LocalizedStringKey, info: LocalizedStringKey,
                                    keyPath: WritableKeyPath<AppSettings.Today, AppSettings.TodayArrangement>,
                                    options: [AppSettings.TodayArrangement]) -> some View {
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
                ForEach(options, id: \.self) { option in
                    Text(Self.title(option)).tag(option)
                }
            }
            .pickerStyle(.segmented)
        }
    }

    private static func title(_ arrangement: AppSettings.TodayArrangement) -> LocalizedStringKey {
        switch arrangement {
        case .stacked: "settings.today.stacked"
        case .sideBySide: "settings.today.sideBySide"
        case .paged: "settings.today.paged"
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
            switch id {
            case .pool: pool
            case .timeline: timeline
            }
        }
        .frame(height: tokens.size(.previewHeight))
        .settingsPreviewFrame()
        .animation(tokens.animation, value: arrangement)
        .accessibilityHidden(true)
    }

    private var pool: some View {
        VStack(spacing: tokens.space(.previewRowGap)) {
            ForEach(0..<Int(tokens.size(.previewRows)), id: \.self) { _ in
                RoundedRectangle(cornerRadius: tokens.radius(.previewItem), style: .continuous)
                    .fill(tokens.color(.plateBackground))
                    .frame(height: tokens.size(.previewRow))
            }
            if arrangement != .stacked { Spacer(minLength: 0) }
        }
        .frame(idealWidth: tokens.size(.previewPoolWidth))
    }

    private var timeline: some View {
        VStack(spacing: 0) {
            ForEach(0..<Int(tokens.size(.previewHours)), id: \.self) { _ in
                Rectangle().fill(tokens.color(.timelineGrid)).frame(height: tokens.size(.gridLine))
                Spacer(minLength: 0)
            }
        }
        .overlay(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: tokens.radius(.previewItem), style: .continuous)
                .fill(tokens.color(.accent).opacity(tokens.opacity(.previewBlock)))
                .frame(height: tokens.size(.previewBlock))
                .padding(.top, tokens.size(.previewBlockTop))
        }
    }
}
