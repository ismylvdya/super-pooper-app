import SwiftUI

/// ⓘ right after a title: a popover with the general, unchanging description of the setting.
struct InfoButton: View {
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
            InfoBubble(text: text).presentationCompactAdaptation(.popover)
        }
    }
}

/// The bubble is as tall as its text (plus padding), but at most a third of the window it is shown in; longer texts
/// scroll.
struct InfoBubble: View {
    @Environment(\.tokens) private var tokens
    /// The whole title of a row that could not show it, above the text.
    var title: Text?
    let text: LocalizedStringKey?
    @State private var textHeight: CGFloat = 0
    @State private var windowHeight: CGFloat?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: tokens.space(.chipGap)) {
                if let title { title.font(tokens.font(.info)).fontWeight(.semibold).foregroundStyle(tokens.color(.infoText)) }
                if let text { Text(text).font(tokens.font(.info)).foregroundStyle(tokens.color(.infoText)) }
            }
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(tokens.space(.infoPadding))
                .onGeometryChange(for: CGFloat.self) { $0.size.height } action: { textHeight = $0 }
        }
        .scrollBounceBehavior(.basedOnSize)
        .frame(width: tokens.size(.infoMaxWidth))
        .frame(height: min(max(textHeight, 1), (windowHeight ?? .infinity) * tokens.ratio(.infoMaxHeight)))
        .background(WindowHeightReader { windowHeight = $0 })
    }
}
