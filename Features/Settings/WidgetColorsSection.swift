import SwiftUI

/// The two colors of the widgets' dark gradient, top and bottom (hex or the system picker, reset to tokens.json).
struct WidgetColorsSection: View {
    static let editable: [ColorToken] = [.widgetTop, .widgetBottom]

    var body: some View {
        PlateSection(header: "settings.widgetColors", hint: "settings.widgetColors.hint") {
            ForEach(Self.editable, id: \.self) { token in
                PlateRow(icon: nil, title: LocalizedStringKey(String("color.") + token.rawValue)) { ColorField(token: token) }
            }
        }
    }
}
