import SwiftUI

/// The checkbox of a task or habit, drawn the same way in the app and in widgets.
/// Partially and Twice look different from Done.
struct MarkGlyph: View {
    @Environment(\.tokens) private var tokens
    @Environment(\.icons) private var icons
    let state: DayItemState
    let color: Color
    /// A small lock: the task comes after something unfinished (it can still be checked).
    var showsLock = false
    var size: CGFloat?

    var body: some View {
        Image(icon: icon, icons: icons)
            .renderingMode(.template)
            .resizable()
            .scaledToFit()
            .symbolRenderingMode(.hierarchical)
            .foregroundStyle(color)
            .frame(width: size ?? tokens.size(.checkbox), height: size ?? tokens.size(.checkbox))
            .overlay(alignment: .bottomTrailing) {
                if showsLock {
                    Image(systemName: icons[.blocked])
                        .font(.system(size: (size ?? tokens.size(.checkbox)) * 0.4))
                        .foregroundStyle(tokens.color(.secondaryText))
                        .offset(x: tokens.size(.badgeOffset), y: tokens.size(.badgeOffset))
                }
            }
            .padding(3)
    }

    private var icon: Icon {
        switch state {
        case .open: .checkboxOpen
        case .marked(.done): .markDone
        case .marked(.partial): .habitMarkPartial
        case .marked(.twice): .habitMarkTwice
        }
    }
}
