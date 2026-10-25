import SwiftUI

/// A title with a smaller grey line under it: an event's time, a habit's week, a sort rule's explanation.
struct TitleDetailLabel<Title: View>: View {
    @Environment(\.tokens) private var tokens
    let detail: Text
    var detailTint: Color?
    @ViewBuilder let title: Title

    var body: some View {
        VStack(alignment: .leading, spacing: tokens.space(.titleDetailGap)) {
            title
            detail.font(tokens.font(.hint)).foregroundStyle(detailTint ?? tokens.color(.secondaryText))
        }
    }
}
