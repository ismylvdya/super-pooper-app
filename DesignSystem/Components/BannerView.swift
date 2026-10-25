import SwiftUI

/// Top banner: up to two lines, tap expands/collapses, swipe up dismisses, hides itself after
/// the token duration.
struct BannerView: View {
    @Environment(\.tokens) private var tokens
    @Environment(\.icons) private var icons
    let text: String
    let icon: Icon?
    let tint: Color
    let onDismiss: () -> Void
    /// When set, a tap runs it (and dismisses) instead of expanding the text.
    var onTap: (() -> Void)?
    @State private var isExpanded = false
    @State private var dragOffset: CGFloat = 0

    var body: some View {
        HStack(alignment: .top, spacing: tokens.space(.iconTextGap)) {
            if let icon { Image(systemName: icons[icon]).foregroundStyle(tint) }
            Text(text)
                .font(tokens.font(.banner))
                .foregroundStyle(tokens.color(.primaryText))
                .lineLimit(isExpanded ? nil : Int(tokens.size(.bannerLines)))
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(tokens.space(.bannerPadding))
        .background(tokens.color(.bannerBackground), in: RoundedRectangle(cornerRadius: tokens.radius(.banner), style: .continuous))
        .shadow(color: tokens.color(.shadow).opacity(tokens.opacity(.bannerShadow)), radius: tokens.size(.bannerShadowRadius), y: tokens.size(.bannerShadowY))
        .padding(.horizontal, tokens.space(.screenHorizontal))
        .padding(.top, tokens.space(.bannerTop))
        .offset(y: min(dragOffset, 0))
        .contentShape(Rectangle())
        .gesture(tapOrSwipe)
        .task(id: text) {
            try? await Task.sleep(for: .seconds(tokens.duration(.bannerAutoHide)))
            if !Task.isCancelled { onDismiss() }
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isStaticText)
        .accessibilityIdentifier("banner")
        .accessibilityAction(named: Text("a11y.dismiss")) { onDismiss() }
    }

    /// One gesture for both: a short touch toggles the full text, a move up dismisses.
    private var tapOrSwipe: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { dragOffset = $0.translation.height }
            .onEnded { value in
                let distance = value.translation.height
                if distance < -tokens.size(.bannerDismissDistance) || value.predictedEndTranslation.height < -tokens.size(.bannerDismissFling) {
                    onDismiss()
                } else {
                    if abs(distance) < tokens.size(.tapSlop), abs(value.translation.width) < tokens.size(.tapSlop) {
                        if let onTap {
                            onTap()
                            onDismiss()
                        } else {
                            isExpanded.toggle()
                        }
                    }
                    withAnimation(tokens.animation) { dragOffset = 0 }
                }
            }
    }
}
