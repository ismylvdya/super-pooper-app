import SwiftUI

/// A group's title, standing in the list as a row of its own (so rows can be dragged across it): a plate's header
/// (`SectionHeader`) a group gap below the group above.
struct ListGroupHeader: View {
    @Environment(\.tokens) private var tokens
    let title: Text

    var body: some View {
        SectionHeader(title: title)
            .padding(.top, tokens.space(.groupGap))
            .frame(maxWidth: .infinity, alignment: .leading)
            .listGroupSpacer()
    }
}
