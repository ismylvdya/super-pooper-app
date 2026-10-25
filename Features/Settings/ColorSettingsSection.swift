import SwiftUI

/// Colors of tasks, habits, done items and the rest: a hex field and the system color picker per
/// color, with a live preview row. Empty = the color from tokens.json.
struct ColorSettingsSection: View {
    @Environment(AppModel.self) private var model
    @Environment(\.tokens) private var tokens

    /// The colors offered here (token names in tokens.json).
    static let editable: [ColorToken] = [.task, .habit, .past, .high, .energy, .heart, .nowLine, .twice, .problem]

    var body: some View {
        PlateSection(header: "settings.colors", info: "info.settings.colors", hint: "settings.colors.hint") {
            preview
            ForEach(Self.editable, id: \.self) { token in
                PlateRow(icon: nil, title: LocalizedStringKey(String("color.") + token.rawValue)) {
                    ColorField(token: token)
                }
            }
        }
    }

    @ViewBuilder private var preview: some View {
        let plan = model.plan(at: model.clock.now)
        let samples = Array(plan.pool.prefix(2)) + Array(plan.pool.filter(\.isHabit).prefix(1))
        VStack(spacing: tokens.space(.poolRowGap)) {
            ForEach(samples) { item in
                TaskRowView(item: item, today: plan.today, isCompact: true).taskPlate(isDone: item.isDone)
            }
        }
        .settingsPreviewFrame()
        .accessibilityHidden(true)
    }
}

/// Hex text field + system color circle + reset for one color token.
struct ColorField: View {
    @Environment(AppModel.self) private var model
    @Environment(\.tokens) private var tokens
    @Environment(\.icons) private var icons
    let token: ColorToken
    @State private var hex = ""

    var body: some View {
        HStack(spacing: tokens.space(.chipGap)) {
            TextField("settings.colors.hex", text: $hex)
                .font(tokens.font(.chip).monospaced())
                .multilineTextAlignment(.trailing)
                .textInputAutocapitalization(.characters)
                .autocorrectionDisabled()
                .frame(width: tokens.size(.hexFieldWidth))
                .onSubmit { save(hex) }
            ColorPicker("", selection: Binding(
                get: { tokens.color(token) },
                set: { save(UIColor($0).hexString) }
            ), supportsOpacity: false)
            .labelsHidden()
            if model.settings.colors[token.rawValue] != nil {
                Button {
                    model.updateSettings { $0.colors[token.rawValue] = nil }
                    hex = ""
                } label: {
                    Image(systemName: icons[.resetOrder]).foregroundStyle(tokens.color(.secondaryText))
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text("settings.colors.reset"))
            }
        }
        .onAppear { hex = model.settings.colors[token.rawValue] ?? "" }
    }

    private func save(_ value: String) {
        let text = value.hasPrefix("#") ? value.uppercased() : "#" + value.uppercased()
        guard UIColor(hex: text) != nil else { return }
        hex = text
        model.updateSettings { $0.colors[token.rawValue] = text }
    }
}
