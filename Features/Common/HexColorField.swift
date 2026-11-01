import SwiftUI

/// The app's one color control, wherever a color is picked: a hex field, the system color circle and, while a color of
/// its own is set, a reset to the default. `stored` is the color as written (nil: the default, which `color` shows);
/// `onChange` gets the new `#RRGGBB`, or nil for the reset.
struct HexColorField: View {
    @Environment(\.tokens) private var tokens
    @Environment(\.icons) private var icons
    let color: Color
    let stored: String?
    let accessibilityID: String
    let onChange: (String?) -> Void
    @State private var hex = ""

    var body: some View {
        HStack(spacing: tokens.space(.chipGap)) {
            TrailingSpaceTextField(placeholder: "settings.colors.hex", text: $hex,
                                   font: .monospacedSystemFont(ofSize: tokens.uiFont(.chip).pointSize, weight: .regular),
                                   capitalization: .characters, accessibilityID: accessibilityID + ".hex") { save(hex) }
                .frame(width: tokens.size(.hexFieldWidth))
            ColorPicker("", selection: Binding(get: { color }, set: { save(UIColor($0).hexString) }), supportsOpacity: false)
                .labelsHidden()
                .accessibilityIdentifier(accessibilityID + ".picker")
            if stored != nil {
                Button { onChange(nil) } label: {
                    Image(systemName: icons[.resetOrder]).foregroundStyle(tokens.color(.secondaryText))
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text("settings.colors.reset"))
                .accessibilityIdentifier(accessibilityID + ".reset")
            }
        }
        .onAppear { hex = stored ?? "" }
        .onChange(of: stored) { hex = stored ?? "" }
    }

    private func save(_ value: String) {
        guard let text = value.storableHexColor else { return }
        hex = text
        onChange(text)
    }
}
