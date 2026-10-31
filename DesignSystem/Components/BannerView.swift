import SwiftUI

/// Top banner: up to two lines, tap expands/collapses, swipe up dismisses, hides itself after
/// the token duration. Under the message each fact has its own element: a count per kind (icon and number), the notes
/// it is about one per line (as many as the message's lines until it is expanded).
struct BannerView: View {
    @Environment(\.tokens) private var tokens
    @Environment(\.icons) private var icons
    let text: String
    let icon: Icon?
    let tint: Color
    var counts: [BannerCount] = []
    var items: [String] = []
    let onDismiss: () -> Void
    /// When set, a tap runs it (and dismisses) instead of expanding the text.
    var onTap: (() -> Void)?
    @State private var isExpanded = false
    @State private var dragOffset: CGFloat = 0

    var body: some View {
        HStack(alignment: .top, spacing: tokens.space(.iconTextGap)) {
            if let icon { Image(systemName: icons[icon]).foregroundStyle(tint) }
            VStack(alignment: .leading, spacing: tokens.space(.titleDetailGap)) {
                Text(text)
                    .lineLimit(isExpanded ? nil : lines)
                if !counts.isEmpty {
                    HStack(spacing: tokens.space(.chipGap)) {
                        ForEach(counts, id: \.self) { count in
                            Label { Text(verbatim: "\(count.value)") } icon: { Image(systemName: icons[count.icon]) }
                                .accessibilityElement(children: .ignore)
                                .accessibilityLabel(Text(verbatim: count.label))
                        }
                    }
                }
                ForEach(shownItems, id: \.self) { item in Text(verbatim: item).lineLimit(1) }
                if shownItems.count < items.count {
                    Text(L10n.format("banner.more", items.count - shownItems.count)).foregroundStyle(tokens.color(.secondaryText))
                }
            }
            .font(tokens.font(.banner))
            .foregroundStyle(tokens.color(.primaryText))
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
        .task(id: text + items.joined()) {
            try? await Task.sleep(for: .seconds(tokens.duration(.bannerAutoHide)))
            if !Task.isCancelled { onDismiss() }
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isStaticText)
        .accessibilityIdentifier("banner")
        .accessibilityAction(named: Text("a11y.dismiss")) { onDismiss() }
    }

    private var lines: Int { Int(tokens.size(.bannerLines)) }

    private var shownItems: [String] { isExpanded ? items : Array(items.prefix(lines)) }

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
