import SwiftUI

/// Where the pool and the timeline sit on Today upright, on Today in landscape and in the widget (each has its own),
/// with live schematic previews.
struct TodaySettingsSection: View {
    /// A place with an arrangement of its own: what it is called, where its choice is kept, what it can show.
    enum Surface: CaseIterable {
        case upright, landscape, widget

        var header: LocalizedStringKey {
            switch self {
            case .upright: "settings.today"
            case .landscape: "settings.landscape"
            case .widget: "settings.widget"
            }
        }

        var hint: LocalizedStringKey {
            switch self {
            case .upright: "settings.today.hint"
            case .landscape: "settings.landscape.hint"
            case .widget: "settings.widget.hint"
            }
        }

        var info: LocalizedStringKey {
            switch self {
            case .upright, .landscape: "info.settings.today.arrangement"
            case .widget: "info.settings.widget.arrangement"
            }
        }

        var setting: WritableKeyPath<AppSettings.Today, AppSettings.TodayArrangement> {
            switch self {
            case .upright: \.arrangement
            case .landscape: \.landscapeArrangement
            case .widget: \.widgetArrangement
            }
        }

        /// The widget has no pages: it offers what it can show (`forWidget`).
        var options: [AppSettings.TodayArrangement] {
            switch self {
            case .upright, .landscape: AppSettings.TodayArrangement.allCases
            case .widget: AppSettings.TodayArrangement.allCases.filter { $0.forWidget == $0 }
            }
        }

        var isLandscape: Bool { self == .landscape }
    }

    @Environment(AppModel.self) private var model
    let surfaces: [Surface]

    var body: some View {
        ForEach(surfaces, id: \.self) { surface in arrangementSection(surface) }
    }

    private func arrangementSection(_ surface: Surface) -> some View {
        let keyPath = surface.setting
        let current = model.settings.today[keyPath: keyPath]
        return PlateSection(header: surface.header, hint: surface.hint) {
            ArrangementPreview(arrangement: current, landscape: surface.isLandscape)
            SettingChoice(icon: .timelineLayout, title: "settings.today.arrangement", info: surface.info,
                          value: (\AppSettings.today).appending(path: keyPath), options: surface.options, prefix: "settings.today.",
                          accessibilityID: "settings.today.arrangement.\(surface)")
        }
    }
}

/// A small drawing of the arrangement: the pool plate and the timeline with an hour grid.
struct ArrangementPreview: View {
    @Environment(AppModel.self) private var model
    @Environment(\.tokens) private var tokens
    @Environment(\.rules) private var rules
    let arrangement: AppSettings.TodayArrangement
    var landscape = false

    var body: some View {
        ScreenLayoutView(layout: model.config.todayLayout(for: arrangement, landscape: landscape)) { id in
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
            ForEach(0..<rules.settingsPreview.poolRows, id: \.self) { _ in
                Color.clear
                    .frame(height: tokens.size(.previewRow))
                    .plate(.previewItem)
            }
            if arrangement != .stacked { Spacer(minLength: 0) }
        }
        .frame(idealWidth: tokens.size(.previewPoolWidth))
    }

    private var timeline: some View {
        VStack(spacing: 0) {
            ForEach(0..<rules.settingsPreview.timelineHours, id: \.self) { _ in
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
