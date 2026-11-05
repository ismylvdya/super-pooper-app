import SwiftUI

extension View {
    /// The row's swipe buttons from the action registry (`actions.json` → `swipes`): only the actions the item offers
    /// now (`AppModel.swipeActions`); the first one of a side runs on a full swipe. `perform` runs the chosen action the
    /// way the row's menu does (a confirmation first, where the action asks for one).
    func actionSwipes(_ swipes: ActionSwipes, item: DayItem?, isToday: Bool = true,
                      perform: @escaping (ActionDefinition) -> Void) -> some View {
        modifier(ActionSwipeButtons(swipes: swipes, item: item, isToday: isToday, perform: perform))
    }
}

private struct ActionSwipeButtons: ViewModifier {
    @Environment(AppModel.self) private var model
    @Environment(\.tokens) private var tokens
    @Environment(\.displayScale) private var scale
    let swipes: ActionSwipes
    let item: DayItem?
    let isToday: Bool
    let perform: (ActionDefinition) -> Void
    /// How tall the row is: its buttons' symbol and title are sized by it.
    @State private var rowHeight: CGFloat?

    func body(content: Content) -> some View {
        let actions = model.swipeActions(swipes, for: item, isToday: isToday)
        content
            // Measured from behind: this modifier put on the row itself takes away what the list reads from it (its insets,
            // background and separator).
            .background { Color.clear.onGeometryChange(for: CGFloat.self) { $0.size.height } action: { rowHeight = $0 } }
            .swipeActions(edge: .leading, allowsFullSwipe: true) { buttons(actions.leading) }
            .swipeActions(edge: .trailing, allowsFullSwipe: true) { buttons(actions.trailing) }
    }

    /// No destructive role: the list would take the row away at once, before the confirmation is answered. The symbol and
    /// title are one image, so the system draws both inside the button on rows of every height, at a size of that height.
    private func buttons(_ actions: [ActionDefinition]) -> some View {
        let iconFont = tokens.uiFont(.swipeIcon), titleFont = tokens.uiFont(.swipeTitle), gap = tokens.space(.swipeIconTitleGap)
        let shrink = SwipeButtonGlyph.shrink(rowHeight: rowHeight, iconFont: iconFont, titleFont: titleFont, gap: gap,
                                             fit: tokens.ratio(.swipeGlyphFit))
        return ForEach(actions, id: \.id) { action in
            Button {
                Haptics.play(action.haptic)
                perform(action)
            } label: {
                Image(uiImage: SwipeButtonGlyph.image(symbol: action.icon, title: L10n.string(action.title),
                                                      iconFont: iconFont.withSize(iconFont.pointSize * shrink),
                                                      titleFont: titleFont.withSize(titleFont.pointSize * shrink),
                                                      gap: gap * shrink, scale: scale))
                    .accessibilityLabel(Text(LocalizedStringKey(action.title)))
            }
            .tint(tokens.color(tint(of: action)))
            .accessibilityIdentifier("swipe.\(action.id.rawValue)")
        }
    }

    private func tint(of action: ActionDefinition) -> ColorToken {
        action.swipeTint.flatMap(ColorToken.init(rawValue:)) ?? (action.destructive ? .destructive : .accentSwipe)
    }
}
