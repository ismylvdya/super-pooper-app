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

    /// One line when the title and the control fit side by side; on narrow screens (iPhone mini) the
    /// control moves under the title instead of squeezing either of them. The whole row takes a tap: a row that
    /// opens a page opens it from the empty space between its title and chevron too.
    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: tokens.space(.iconTextGap)) {
                label.fixedSize()
                Spacer(minLength: tokens.space(.chipGap))
                trailing.fixedSize()
            }
            VStack(alignment: .leading, spacing: tokens.space(.chipGap)) {
                label
                HStack {
                    Spacer(minLength: 0)
                    trailing
                }
            }
        }
        .padding(.leading, indent ? tokens.space(.childIndent) : 0)
        .contentShape(Rectangle())
    }

    private var label: some View {
        HStack(spacing: tokens.space(.iconTextGap)) {
            if let icon {
                IconGlyph(icon, font: .rowTitle)
                    .foregroundStyle(iconTint ?? tint ?? tokens.color(.accent))
                    .frame(width: tokens.size(.iconColumn))
            }
            HStack(spacing: tokens.space(.titleInfoGap)) {
                title.foregroundStyle(tint ?? tokens.color(.primaryText))
                if let info { InfoButton(text: info, tint: tint ?? tokens.color(.primaryText)) }
            }
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
