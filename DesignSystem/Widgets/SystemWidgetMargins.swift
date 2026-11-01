#if DEBUG
import SwiftUI

extension View {
    /// The margins the system puts around a widget's content, for a widget view the app draws itself (the widget gallery,
    /// previews). In a widget the system puts its own (`widgetContentMargins`).
    func systemWidgetMargins() -> some View {
        modifier(SystemWidgetMargins())
    }
}

private struct SystemWidgetMargins: ViewModifier {
    @Environment(\.tokens) private var tokens

    func body(content: Content) -> some View {
        content.padding(tokens.space(.widgetMargin))
    }
}
#endif
