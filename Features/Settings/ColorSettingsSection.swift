import SwiftUI

/// Colors of tasks, habits, done items and the rest: a hex field and the system color picker per
/// color, with a live preview row. Empty = the color from tokens.json.
struct ColorSettingsSection: View {
    @Environment(AppModel.self) private var model
    @Environment(\.tokens) private var tokens
    @Environment(\.rules) private var rules

    var body: some View {
        PlateSection(header: "settings.colors", info: "info.settings.colors", hint: "settings.colors.hint") {
            preview
            ForEach(tokens.editableColors[.general], id: \.self) { token in
                PlateRow(icon: nil, title: LocalizedStringKey(String("color.") + token.rawValue)) {
                    ThemeColorField(token: token)
                }
            }
        }
    }

    @ViewBuilder private var preview: some View {
        let plan = model.plan(at: model.clock.now)
        let preview = rules.settingsPreview
        let samples = Array(plan.pool.prefix(preview.colorRows)) + Array(plan.pool.filter(\.isHabit).prefix(preview.colorHabitRows))
        VStack(spacing: tokens.space(.poolRowGap)) {
            ForEach(samples) { item in
                TaskRowView(item: item, isCompact: true).taskPlate(isDone: item.isDone)
            }
        }
        .settingsPreviewFrame()
        .accessibilityHidden(true)
    }
}

/// The color of one token, editable (empty = the color from tokens.json).
struct ColorField: View {
    @Environment(AppModel.self) private var model
    @Environment(\.tokens) private var tokens
    let token: ColorToken

    var body: some View {
        HexColorField(color: tokens.color(token), stored: model.settings.colors[token.rawValue],
                      accessibilityID: String("color.") + token.rawValue) { hex in
            model.updateSettings { $0.colors[token.rawValue] = hex }
        }
    }
}

/// One token's color for each theme: a color circle under the sun and one under the moon, and a reset while either is the
/// user's own. A color set only for the light theme stands in both until the dark one gets its own.
struct ThemeColorField: View {
    @Environment(AppModel.self) private var model
    @Environment(\.tokens) private var tokens
    @Environment(\.icons) private var icons
    let token: ColorToken

    var body: some View {
        HStack(spacing: tokens.space(.chipGap)) {
            picker(.light, key: token.rawValue, icon: .themeLight)
            picker(.dark, key: DesignTokens.darkColorKey(token), icon: .themeDark)
            if isOwn {
                Button {
                    model.updateSettings { settings in
                        settings.colors[token.rawValue] = nil
                        settings.colors[DesignTokens.darkColorKey(token)] = nil
                    }
                } label: {
                    Image(systemName: icons[.resetOrder]).foregroundStyle(tokens.color(.secondaryText))
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text("settings.colors.reset"))
                .accessibilityIdentifier("color.\(token.rawValue).reset")
            }
        }
    }

    private var isOwn: Bool {
        model.settings.colors[token.rawValue] != nil || model.settings.colors[DesignTokens.darkColorKey(token)] != nil
    }

    private func picker(_ style: UIUserInterfaceStyle, key: String, icon: Icon) -> some View {
        let shown = tokens.uiColor(token).resolvedColor(with: UITraitCollection(userInterfaceStyle: style))
        return HStack(spacing: tokens.space(.badgeGap)) {
            Image(systemName: icons[icon]).font(tokens.font(.chip)).foregroundStyle(tokens.color(.secondaryText))
            ColorPicker("", selection: Binding(get: { Color(uiColor: shown) }, set: { color in
                model.updateSettings { $0.colors[key] = UIColor(color).hexString }
            }), supportsOpacity: false)
            .labelsHidden()
            .accessibilityIdentifier("color.\(key).picker")
        }
    }
}
