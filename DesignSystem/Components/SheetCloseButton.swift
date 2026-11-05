import SwiftUI

/// Closes the sheet it stands in. Nothing in the app is confirmed by a button: what the sheet edits is saved as it closes.
struct SheetCloseButton: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.icons) private var icons

    var body: some View {
        Button { dismiss() } label: { Image(systemName: icons[.close]) }
            .accessibilityLabel(Text("common.close"))
    }
}
