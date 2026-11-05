import SwiftUI

/// A row inside a plate: icon column, title with ⓘ right after it, trailing control.
struct PlateRow<Trailing: View>: View {
    @Environment(\.tokens) private var tokens
    let icon: Icon?
    let title: Text
    let info: LocalizedStringKey?
    let tint: Color?
    /// The icon's own color (a property's color, e.g. the pink heart) while the title stays as it is.
    let iconTint: Color?
    let indent: Bool
    let trailing: Trailing

    init(icon: Icon?, title: LocalizedStringKey, info: LocalizedStringKey? = nil, tint: Color? = nil, iconTint: Color? = nil,
         indent: Bool = false, @ViewBuilder trailing: () -> Trailing) {
        self.init(icon: icon, title: Text(title), info: info, tint: tint, iconTint: iconTint, indent: indent, trailing: trailing)
    }

    /// A title already made into text, e.g. `Text(verbatim:)` for a note's name.
    init(icon: Icon?, title: Text, info: LocalizedStringKey? = nil, tint: Color? = nil, iconTint: Color? = nil, indent: Bool = false,
         @ViewBuilder trailing: () -> Trailing) {
        self.icon = icon
        self.title = title
        self.info = info
        self.tint = tint
        self.iconTint = iconTint
        self.indent = indent
        self.trailing = trailing()
    }

    /// One line whatever the screen: when the title and the control do not fit side by side, the title gives way and
    /// dissolves at its right, the control stays whole; a hold on it shows the whole title and its description
    /// (`PlateRowTitle`). The whole row takes a tap: a row that opens a page opens it from the empty space between its
    /// title and chevron too.
    var body: some View {
        ViewThatFits(in: .horizontal) {
            row(isFading: false)
            row(isFading: true)
        }
        .padding(.leading, indent ? tokens.space(.childIndent) : 0)
        .contentShape(Rectangle())
    }

    private func row(isFading: Bool) -> some View {
        HStack(spacing: tokens.space(.iconTextGap)) {
            if let icon {
                IconGlyph(icon, font: .rowTitle)
                    .foregroundStyle(iconTint ?? tint ?? tokens.color(.accentIcon))
                    .frame(width: tokens.size(.iconColumn))
            }
            HStack(spacing: tokens.space(.titleInfoGap)) {
                let shown = title.foregroundStyle(tint ?? tokens.color(.primaryText))
                if isFading {
                    PlateRowTitle(title: shown, wholeTitle: title, info: info)
                } else {
                    shown.lineLimit(1).fixedSize()
                }
                if let info { InfoButton(text: info, tint: tint ?? tokens.color(.primaryText)) }
            }
            if !isFading { Spacer(minLength: tokens.space(.chipGap)) }
            trailing.fixedSize()
        }
    }
}

/// A row's title short of room: one line that dissolves at its right, and held, a bubble with the whole of it and the
/// row's description.
private struct PlateRowTitle<Shown: View>: View {
    @Environment(\.tokens) private var tokens
    let title: Shown
    let wholeTitle: Text
    let info: LocalizedStringKey?
    @State private var isHolding = false

    var body: some View {
        title
            .lineLimit(1)
            .fixedSize()
            .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)
            .clipped()
            .mask {
                HStack(spacing: 0) {
                    Color.black
                    LinearGradient(colors: [.black, .clear], startPoint: .leading, endPoint: .trailing).frame(width: tokens.size(.titleFade))
                }
            }
            .contentShape(Rectangle())
            .simultaneousGesture(LongPressGesture().onEnded { _ in isHolding = true })
            .popover(isPresented: $isHolding) {
                InfoBubble(title: wholeTitle, text: info).presentationCompactAdaptation(.popover)
            }
    }
}

extension PlateRow where Trailing == EmptyView {
    init(icon: Icon?, title: LocalizedStringKey, info: LocalizedStringKey? = nil, tint: Color? = nil, indent: Bool = false) {
        self.init(icon: icon, title: title, info: info, tint: tint, indent: indent) { EmptyView() }
    }

    init(icon: Icon?, title: Text, info: LocalizedStringKey? = nil, tint: Color? = nil, indent: Bool = false) {
        self.init(icon: icon, title: title, info: info, tint: tint, indent: indent) { EmptyView() }
    }
}
