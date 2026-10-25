import SwiftUI

extension View {
    /// The small frame a live preview sits in on a settings page (colors, habits, Today, timeline): the
    /// screen background with rounded corners, not touchable.
    func settingsPreviewFrame() -> some View {
        modifier(SettingsPreviewFrame())
    }
}

private struct SettingsPreviewFrame: ViewModifier {
    @Environment(\.tokens) private var tokens

    func body(content: Content) -> some View {
        content
            .padding(tokens.space(.chipGap))
            .background(tokens.color(.screenBackground), in: RoundedRectangle(cornerRadius: tokens.radius(.timelineItem), style: .continuous))
            .allowsHitTesting(false)
    }
}
