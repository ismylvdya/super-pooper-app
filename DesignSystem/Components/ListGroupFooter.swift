import SwiftUI

/// A hint under a group: a plate's hint (`PlateHint`).
struct ListGroupFooter: View {
    let text: Text

    var body: some View {
        PlateHint(text: text)
            .frame(maxWidth: .infinity, alignment: .leading)
            .listGroupSpacer()
    }
}
