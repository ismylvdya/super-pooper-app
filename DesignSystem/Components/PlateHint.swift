import SwiftUI

/// The hint under a plate (or under a group of a grouped list, `ListGroupFooter`).
struct PlateHint: View {
    @Environment(\.tokens) private var tokens
    let text: Text

    var body: some View {
        text
            .secondaryText(.hint)
            .padding(.horizontal, tokens.space(.plateInner))
            .padding(.top, tokens.space(.hintToPlate))
    }
}
