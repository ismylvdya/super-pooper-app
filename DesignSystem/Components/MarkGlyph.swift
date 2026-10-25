import SwiftUI

/// The checkbox of a task or habit, drawn the same way in the app and in widgets.
/// Partially and Twice look different from Done.
struct MarkGlyph: View {
    @Environment(\.tokens) private var tokens
    @Environment(\.icons) private var icons
    let state: DayItemState
    let color: Color
    var size: CGFloat?

    var body: some View {
        Image(icon: icon, icons: icons)
            .renderingMode(.template)
            .resizable()
            .scaledToFit()
            .symbolRenderingMode(.hierarchical)
            .foregroundStyle(color)
            .frame(width: size ?? tokens.size(.checkbox), height: size ?? tokens.size(.checkbox))
            .padding(tokens.space(.markPadding))
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
