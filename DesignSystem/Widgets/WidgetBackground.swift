import SwiftUI

/// The background of the app's widgets. Dark, it is the gradient of Apple's own widgets (Calendar): a little lighter
/// at the top (`widgetTop` → `widgetBottom`, editable in Settings), so the widgets sit with them. Light, each widget
/// keeps its flat color; the two tokens have the dark values in both themes, so their settings fields show them.
/// The widget's own tokens (with the user's colors) come in as a value: a container background is drawn apart from
/// the widget's view and does not see the tokens it puts in the environment.
struct WidgetBackground: View {
    @Environment(\.colorScheme) private var colorScheme
    let tokens: DesignTokens
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
