import SwiftUI

/// The minus that takes one item out of a list on a page: a link, an event, a reminder time.
struct RemoveButton: View {
    @Environment(\.tokens) private var tokens
    @Environment(\.icons) private var icons
    let label: LocalizedStringKey
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: icons[.remove]).foregroundStyle(tokens.color(.destructive))
        }
        .buttonStyle(.borderless)
        .accessibilityLabel(Text(label))
    }
}
