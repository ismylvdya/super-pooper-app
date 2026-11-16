import SwiftUI

/// A group's title, standing in the list as a row of its own (so rows can be dragged across it): a plate's header
/// (`SectionHeader`) a group gap below the group above.
struct ListGroupHeader: View {
    @Environment(\.tokens) private var tokens
    let title: Text
    /// Told where the header's middle stands on the screen, for a "+" dragged over the list.
    var onMid: ((CGFloat) -> Void)?

    init(title: Text, onMid: ((CGFloat) -> Void)? = nil) {
        self.title = title
        self.onMid = onMid
    }

    var body: some View {
        SectionHeader(title: title)
            .padding(.top, tokens.space(.groupGap))
            .frame(maxWidth: .infinity, alignment: .leading)
            .onGeometryChange(for: CGFloat.self) { $0.frame(in: .global).midY } action: { onMid?($0) }
            .listGroupSpacer()
    }
}
