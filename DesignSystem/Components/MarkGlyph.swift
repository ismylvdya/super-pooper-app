import SwiftUI

/// The checkbox of a task or habit, drawn the same way in the app and in widgets.
/// Partially and Twice look different from Done.
struct MarkGlyph: View {
    @Environment(\.tokens) private var tokens
    @Environment(\.icons) private var icons
    let state: DayItemState
    let color: Color
    var isBlocked = false
    var size: CGFloat?

    var body: some View {
        Image(systemName: icons[icon])
            .resizable()
            .scaledToFit()
            .symbolRenderingMode(.hierarchical)
            .foregroundStyle(isBlocked ? tokens.color(.tertiaryText) : color)
            .frame(width: size ?? tokens.size(.checkbox), height: size ?? tokens.size(.checkbox))
            .overlay(alignment: .bottomTrailing) {
                if isBlocked {
                    Image(systemName: icons[.blocked])
                        .font(.system(size: (size ?? tokens.size(.checkbox)) * 0.4))
                        .foregroundStyle(tokens.color(.secondaryText))
                        .offset(x: 3, y: 3)
                }
            }
            .padding(3)
    }

    private var icon: Icon {
        switch state {
        case .open: .checkboxOpen
        case .marked(.done): .markDone
        case .marked(.partial): .markPartial
        case .marked(.twice): .markTwice
        }
    }
}
