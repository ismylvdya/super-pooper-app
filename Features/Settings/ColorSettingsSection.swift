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
                    ColorField(token: token)
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
