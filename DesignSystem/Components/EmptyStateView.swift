import SwiftUI

/// A clear empty screen with one action (e.g. "Choose vault folder").
struct EmptyStateView: View {
    @Environment(\.tokens) private var tokens
    @Environment(\.icons) private var icons
    let icon: Icon
    let title: LocalizedStringKey
    let message: LocalizedStringKey
    var actionTitle: LocalizedStringKey?
    var action: (() -> Void)?

    var body: some View {
        VStack(spacing: tokens.space(.groupGap)) {
            Image(systemName: icons[icon])
                .font(.system(size: 52))
                .foregroundStyle(tokens.color(.accent))
            Text(title).font(tokens.font(.emptyTitle)).multilineTextAlignment(.center)
            Text(message)
                .font(tokens.font(.emptyBody))
                .foregroundStyle(tokens.color(.secondaryText))
                .multilineTextAlignment(.center)
            if let actionTitle, let action {
                Button(action: action) { Text(actionTitle).fontWeight(.semibold) }
                    .buttonStyle(.borderedProminent)
                    .tint(tokens.color(.accent))
            }
        }
        .padding(tokens.space(.screenHorizontal) * 2)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
