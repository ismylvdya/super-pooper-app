import SwiftUI

/// The "…" button: a small popover with the registry's actions the task store can do, each with its icon on the left
/// in the same color as its title (system menus put icons on the right). The chosen action runs once the popover is gone:
/// a confirmation it asks for is never presented while the popover is still closing (it could be dropped then).
struct ActionPopoverButton: View {
    @Environment(AppModel.self) private var model
    @Environment(\.tokens) private var tokens
    @Environment(\.icons) private var icons
    let menu: ActionMenu
    var accessibilityID = "more"
    let perform: (ActionDefinition) -> Void
    @State private var isPresented = false
    @State private var chosen: ActionDefinition?

    var body: some View {
        Button { isPresented = true } label: { Image(systemName: icons[.more]) }
            .tint(tokens.color(.accent))
            .accessibilityLabel(Text("taskPage.more"))
            .accessibilityIdentifier(accessibilityID)
            .popover(isPresented: $isPresented) {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(model.menuEntries(menu, for: nil).map(\.action).enumerated()), id: \.element.id) { index, action in
                        if index > 0 { Divider() }
                        Button {
                            chosen = action
                            isPresented = false
                            Haptics.play(action.haptic)
                        } label: {
                            HStack(spacing: tokens.space(.iconTextGap)) {
                                Image(systemName: action.icon).frame(width: tokens.size(.iconColumn))
                                Text(LocalizedStringKey(action.title))
                                Spacer(minLength: 0)
                            }
                            .font(tokens.font(.popoverAction))
                            .foregroundStyle(action.destructive ? tokens.color(.destructive) : tokens.color(.primaryText))
                            .padding(.vertical, tokens.space(.popoverRowVertical))
                            .padding(.horizontal, tokens.space(.plateInner))
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityIdentifier("action.\(action.id.rawValue)")
                    }
                }
                .frame(minWidth: tokens.size(.actionPopoverWidth))
                .fixedSize()
                .presentationCompactAdaptation(.popover)
                .onDisappear {
                    guard let action = chosen else { return }
                    chosen = nil
                    perform(action)
                }
            }
    }
}
