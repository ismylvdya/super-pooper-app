import SwiftUI

/// A clear empty screen with one action (e.g. "Choose vault folder").
struct EmptyStateView: View {
    @Environment(\.tokens) private var tokens
    @Environment(\.icons) private var icons
    let icon: Icon
    let title: LocalizedStringKey
    let message: Text
    let actionTitle: LocalizedStringKey?
    let action: (() -> Void)?

    init(icon: Icon, title: LocalizedStringKey, message: LocalizedStringKey, actionTitle: LocalizedStringKey? = nil,
         action: (() -> Void)? = nil) {
        self.init(icon: icon, title: title, message: Text(message), actionTitle: actionTitle, action: action)
    }

    /// A message already made into text, e.g. `Text(verbatim:)` for an error the system wrote.
    init(icon: Icon, title: LocalizedStringKey, message: Text, actionTitle: LocalizedStringKey? = nil,
         action: (() -> Void)? = nil) {
        self.icon = icon
        self.title = title
        self.message = message
        self.actionTitle = actionTitle
        self.action = action
    }

    var body: some View {
        VStack(spacing: tokens.space(.groupGap)) {
            Image(systemName: icons[icon])
                .font(tokens.font(.emptyIcon))
                .foregroundStyle(tokens.color(.accent))
            Text(title).font(tokens.font(.emptyTitle)).multilineTextAlignment(.center)
            message
                .font(tokens.font(.emptyBody))
                .foregroundStyle(tokens.color(.secondaryText))
                .multilineTextAlignment(.center)
            if let actionTitle, let action {
                Button(action: action) { Text(actionTitle).font(tokens.font(.emptyAction)) }
                    .buttonStyle(.borderedProminent)
                    .tint(tokens.color(.accent))
            }
        }
        .padding(tokens.space(.screenHorizontal) * 2)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
