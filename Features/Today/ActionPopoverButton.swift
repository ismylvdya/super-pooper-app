import SwiftUI

/// The "…" button: a small popover with the registry's actions, each with its icon on the left in the
/// same color as its title (system menus put icons on the right).
struct ActionPopoverButton: View {
    @Environment(\.actions) private var actions
    @Environment(\.tokens) private var tokens
    @Environment(\.icons) private var icons
    let menu: ActionMenu
    var accessibilityID = "more"
    let perform: (ActionDefinition) -> Void
    @State private var isPresented = false

    var body: some View {
        Button { isPresented = true } label: { Image(systemName: icons[.more]) }
            .tint(tokens.color(.accent))
            .accessibilityLabel(Text("taskPage.more"))
            .accessibilityIdentifier(accessibilityID)
            .popover(isPresented: $isPresented) {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(actions.actions(in: menu).enumerated()), id: \.element.id) { index, action in
                        if index > 0 { Divider() }
                        Button {
                            isPresented = false
                            Haptics.play(action.haptic)
                            perform(action)
                        } label: {
                            HStack(spacing: tokens.space(.iconTextGap)) {
                                Image(systemName: action.icon).frame(width: tokens.size(.iconColumn))
                                Text(LocalizedStringKey(action.title))
                                Spacer(minLength: 0)
                            }
                            .foregroundStyle(action.destructive ? tokens.color(.destructive) : tokens.color(.primaryText))
                            .padding(.vertical, tokens.space(.rowVertical))
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
            }
    }
}
