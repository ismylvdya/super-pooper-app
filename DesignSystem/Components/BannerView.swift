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
        .shadow(color: .black.opacity(0.12), radius: 12, y: 4)
        .padding(.horizontal, tokens.space(.screenHorizontal))
        .padding(.top, tokens.space(.bannerTop))
        .offset(y: min(dragOffset, 0))
        .onTapGesture { withAnimation(tokens.animation) { isExpanded.toggle() } }
        .gesture(DragGesture(minimumDistance: 8)
            .onChanged { dragOffset = $0.translation.height }
            .onEnded { value in
                if value.translation.height < -20 { onDismiss() } else { withAnimation(tokens.animation) { dragOffset = 0 } }
            })
        .task(id: text) {
            try? await Task.sleep(for: .seconds(tokens.duration(.bannerAutoHide)))
            if !Task.isCancelled { onDismiss() }
        }
        .accessibilityAddTraits(.isStaticText)
    }
}
