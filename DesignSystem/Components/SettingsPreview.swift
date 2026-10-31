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

    /// Clipped to its frame: the pages of a paged preview reach past it.
    func body(content: Content) -> some View {
        content
            .padding(tokens.space(.previewInset))
            .plate(.previewFrame, fill: tokens.color(.screenBackground), clipsContent: true)
            .allowsHitTesting(false)
    }
}
