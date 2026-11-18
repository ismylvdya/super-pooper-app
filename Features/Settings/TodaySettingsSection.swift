import SwiftUI

/// Where the pool and the timeline sit on Today upright and in the widget (each has its own; in landscape it is always the
/// pool on the left and the timeline on the right, D-191),
/// with live schematic previews.
struct TodaySettingsSection: View {
    /// A place with an arrangement of its own: what it is called, where its choice is kept, what it can show.
    enum Surface: CaseIterable {
        case upright, widget

        var header: LocalizedStringKey {
            switch self {
            case .upright: "settings.today"
            case .widget: "settings.widget"
            }
        }

        var hint: LocalizedStringKey {
            switch self {
            case .upright: "settings.today.hint"
            case .widget: "settings.widget.hint"
            }
        }

        var info: LocalizedStringKey {
            switch self {
            case .upright: "info.settings.today.arrangement"
            case .widget: "info.settings.widget.arrangement"
            }
        }

        var setting: WritableKeyPath<AppSettings.Today, AppSettings.TodayArrangement> {
            switch self {
            case .upright: \.arrangement
            case .widget: \.widgetArrangement
            }
        }

        /// The widget has no pages: it offers what it can show (`forWidget`).
        var options: [AppSettings.TodayArrangement] {
            switch self {
            case .upright: AppSettings.TodayArrangement.allCases
            case .widget: AppSettings.TodayArrangement.allCases.filter { $0.forWidget == $0 }
            }
        }
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
            // Upright, Today is always pages; only the widget has a choice.
            ArrangementPreview(arrangement: surface == .upright ? .paged : current)
            if surface == .widget {
                SettingChoice(icon: .timelineLayout, title: "settings.today.arrangement", info: surface.info,
                              value: (\AppSettings.today).appending(path: keyPath), options: surface.options, prefix: "settings.today.",
                              accessibilityID: "settings.today.arrangement.\(surface)")
            }
            // On pages: how much of the other page stays in sight; the border between them moves.
            if surface == .upright {
                SettingSlider(icon: nil, title: "settings.today.timelinePeek", info: "info.settings.today.timelinePeek",
                              value: \.today.timelinePeek, limits: model.config.rules.limits.pagePeek,
                              accessibilityID: "settings.today.timelinePeek") { PercentText(value: $0) }
                SettingSlider(icon: nil, title: "settings.today.poolPeek", info: "info.settings.today.poolPeek",
                              value: \.today.poolPeek, limits: model.config.rules.limits.pagePeek,
                              accessibilityID: "settings.today.poolPeek") { PercentText(value: $0) }
            }
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
