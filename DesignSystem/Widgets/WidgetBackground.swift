import SwiftUI

/// The background of the app's widgets. Dark, it is the gradient of Apple's own widgets (Calendar): a little lighter
/// at the top (`widgetTop` → `widgetBottom`), so the widgets sit with them. Light, each widget keeps its flat color.
struct WidgetBackground: View {
    @Environment(\.tokens) private var tokens
    @Environment(\.colorScheme) private var colorScheme
    /// The flat color of the light theme.
    let light: ColorToken

    var body: some View {
        if colorScheme == .dark {
            LinearGradient(colors: [tokens.color(.widgetTop), tokens.color(.widgetBottom)], startPoint: .top, endPoint: .bottom)
        } else {
            tokens.color(light)
        }
    }
}
