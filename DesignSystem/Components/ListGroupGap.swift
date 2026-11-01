import SwiftUI

/// The space above a group without a title.
struct ListGroupGap: View {
    @Environment(\.tokens) private var tokens

    var body: some View {
        Color.clear.frame(height: tokens.space(.groupGap)).listGroupSpacer()
    }
}
