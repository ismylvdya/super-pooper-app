import SwiftUI
import WidgetKit

extension View {
    /// What every widget of the app sits in: the tokens with the user's settings (colors, sizes) for the widget and its
    /// background (flat `light` in the light theme), and the app's calendar.
    func widgetChrome(_ source: WidgetDataSource?, light: ColorToken) -> some View {
        modifier(WidgetChrome(source: source, light: light))
    }
}

private struct WidgetChrome: ViewModifier {
    @Environment(\.tokens) private var tokens
    let source: WidgetDataSource?
    let light: ColorToken

    func body(content: Content) -> some View {
        let widgetTokens = (source.map { $0.config.tokens.applying($0.settings, limits: $0.config.rules.limits) } ?? tokens).forWidget()
        content
            .containerBackground(for: .widget) { WidgetBackground(tokens: widgetTokens, light: light) }
            .designTokens(widgetTokens)
            .appCalendar(source?.calendar ?? AppCalendar.make())
    }
}

/// A widget with nothing to show yet says why in one line.
struct WidgetEmptyText: View {
    @Environment(\.tokens) private var tokens
    let text: LocalizedStringKey

    var body: some View {
        Text(text).font(tokens.font(.widgetCaption)).foregroundStyle(tokens.color(.secondaryText)).padding()
    }
}
