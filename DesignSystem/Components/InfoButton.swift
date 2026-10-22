import SwiftUI

/// ⓘ right after a title: a popover with the general, unchanging description of the setting.
struct InfoButton: View {
    @Environment(\.tokens) private var tokens
    @Environment(\.icons) private var icons
    let text: LocalizedStringKey
    let tint: Color
    @State private var isPresented = false

    var body: some View {
        Button {
            isPresented = true
        } label: {
            Image(systemName: icons[.info])
                .imageScale(.small)
                .foregroundStyle(tint)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text("a11y.info"))
        .popover(isPresented: $isPresented) {
            Text(text)
                .font(tokens.font(.info))
                .foregroundStyle(tokens.color(.infoText))
                .padding(tokens.space(.infoPadding))
                .frame(maxWidth: tokens.size(.infoMaxWidth))
                .fixedSize(horizontal: false, vertical: true)
                .presentationCompactAdaptation(.popover)
        }
    }
}
