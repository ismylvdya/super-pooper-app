import SwiftUI

/// Top banner just under the bar's round buttons (`BannerPlacement`): collapsed it is one line exactly as tall as they
/// are (the first note it is about after the message, how many more beside it, the counts, each its own element); a tap
/// expands it to the whole message and under it the
/// notes it is about, one per line, and collapses it again. A swipe up dismisses it; it hides itself after `hidesAfter`
/// (`banners.autoHideSeconds` unless given). A banner offering Undo has the button at its end.
struct BannerView: View {
    @Environment(\.tokens) private var tokens
    @Environment(\.rules) private var rules
    @Environment(\.icons) private var icons
    @Environment(\.bannerInSheet) private var isInSheet
    let text: String
    let icon: Icon?
    let tint: Color
    var counts: [BannerCount] = []
    var items: [String] = []
    var hidesAfter: Double?
    let onDismiss: () -> Void
    /// When set, a tap runs it (and dismisses) instead of expanding the text.
    var onTap: (() -> Void)?
    /// When set, the Undo button runs it (and dismisses).
    var onUndo: (() -> Void)?
    @State private var isExpanded = false
    @State private var dragOffset: CGFloat = 0

    var body: some View {
        HStack(spacing: tokens.space(.iconTextGap)) {
            message
                .accessibilityElement(children: .combine)
                // Read out whole even while collapsed: the notes too, not only the first one shown.
                .accessibilityLabel(Text(verbatim: ([text] + counts.map(\.label) + items).joined(separator: "\n")))
                .accessibilityAddTraits(.isStaticText)
                .accessibilityIdentifier("banner")
                .accessibilityAction(named: Text("a11y.dismiss")) { onDismiss() }
            if let onUndo {
                Button {
                    onUndo()
                    onDismiss()
                } label: {
                    Text("banner.undo").font(tokens.font(.banner)).fontWeight(.semibold)
                }
                .buttonStyle(.bordered)
                .buttonBorderShape(.capsule)
                .controlSize(.small)
                .tint(tokens.color(.accent))
                .accessibilityIdentifier("banner.undo")
            }
        }
        .padding(.horizontal, tokens.space(.bannerPadding))
        .padding(.vertical, isExpanded ? tokens.space(.bannerPadding) : 0)
        .frame(minHeight: tokens.bannerPlacement.height, maxHeight: isExpanded ? nil : tokens.bannerPlacement.height)
        .systemLook(.bannerCard)
        // Only the card takes touches: the bar's buttons above it stay free.
        .contentShape(Rectangle())
        .gesture(tapOrSwipe)
        .padding(.horizontal, tokens.bannerPlacement.side)
        .padding(.top, isInSheet ? tokens.bar(.sheetBarTop) + tokens.bar(.uprightBarButton) + tokens.bar(.bannerBelowButtons) : tokens.bannerPlacement.top)
        .offset(y: min(dragOffset, 0))
        .task(id: text + items.joined()) {
            try? await Task.sleep(for: .seconds(hidesAfter ?? rules.banners.autoHideSeconds))
            if !Task.isCancelled { onDismiss() }
        }
    }

    private var message: some View {
        HStack(alignment: isExpanded ? .top : .center, spacing: tokens.space(.iconTextGap)) {
            if let icon { Image(systemName: icons[icon]).foregroundStyle(tint) }
            if isExpanded {
                VStack(alignment: .leading, spacing: tokens.space(.titleDetailGap)) {
                    Text(text)
                    if !counts.isEmpty { countRow }
                    ForEach(items, id: \.self) { item in Text(verbatim: item).lineLimit(1) }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                HStack(spacing: tokens.space(.iconTextGap)) {
                    Text(text).lineLimit(1).layoutPriority(1)
                    // The first note it is about, in its own place after the message; the rest after a tap.
                    if let first = items.first {
                        Text(verbatim: first).fontWeight(.semibold).lineLimit(1)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                if items.count > 1 {
                    Text(verbatim: "+\(items.count - 1)").foregroundStyle(tokens.color(.secondaryText)).fixedSize()
                }
                if !counts.isEmpty { countRow.fixedSize() }
            }
        }
        .font(tokens.font(.banner))
        .foregroundStyle(tokens.color(.primaryText))
    }

    /// A count per kind of change: its icon and number.
    private var countRow: some View {
        HStack(spacing: tokens.space(.chipGap)) {
            ForEach(counts, id: \.self) { count in
                Label { Text(verbatim: "\(count.value)") } icon: { Image(systemName: icons[count.icon]) }
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(Text(verbatim: count.label))
            }
        }
    }

    /// One gesture for both: a short touch toggles the full text, a move up dismisses.
    private var tapOrSwipe: some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { dragOffset = $0.translation.height }
            .onEnded { value in
                let distance = value.translation.height
                if distance < -rules.gestures.bannerDismissDistance || value.predictedEndTranslation.height < -rules.gestures.bannerDismissFling {
                    onDismiss()
                } else {
                    if abs(distance) < rules.gestures.tapSlop, abs(value.translation.width) < rules.gestures.tapSlop {
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

private struct BannerInSheetKey: EnvironmentKey {
    static let defaultValue = false
}

extension EnvironmentValues {
    /// The banner stands on a sheet's bar, whose buttons start further under its top than a screen's.
    var bannerInSheet: Bool {
        get { self[BannerInSheetKey.self] }
        set { self[BannerInSheetKey.self] = newValue }
    }
}
