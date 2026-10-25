import SwiftUI

/// A settings-style group: header above, rounded plate with rows, hint below (manifest specs).
struct PlateSection<Content: View>: View {
    @Environment(\.tokens) private var tokens
    let header: Text?
    let info: LocalizedStringKey?
    let hint: Text?
    let content: Content

    init(header: LocalizedStringKey?, info: LocalizedStringKey? = nil, hint: LocalizedStringKey? = nil,
         @ViewBuilder content: () -> Content) {
        self.init(header: header.map { Text($0) }, info: info, hintText: hint.map { Text($0) }, content: content)
    }

    /// A hint already made into text: the user's own words go in `Text(verbatim:)`, so they show as typed
    /// and not as a key or Markdown.
    init(header: LocalizedStringKey?, info: LocalizedStringKey? = nil, hint: Text, @ViewBuilder content: () -> Content) {
        self.init(header: header.map { Text($0) }, info: info, hintText: hint, content: content)
    }

    init(header: Text, info: LocalizedStringKey? = nil, hint: Text, @ViewBuilder content: () -> Content) {
        self.init(header: header, info: info, hintText: hint, content: content)
    }

    private init(header: Text?, info: LocalizedStringKey?, hintText: Text?, @ViewBuilder content: () -> Content) {
        self.header = header
        self.info = info
        self.hint = hintText
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let header { PlateHeader(title: header, info: info) }
            Plate { content }
            if let hint {
                hint
                    .font(tokens.font(.hint))
                    .foregroundStyle(tokens.color(.secondaryText))
                    .padding(.horizontal, tokens.space(.plateInner))
                    .padding(.top, tokens.space(.hintToPlate))
            }
        }
    }
}

/// The title above a plate, with an optional ⓘ.
struct PlateHeader: View {
    @Environment(\.tokens) private var tokens
    let title: Text
    var info: LocalizedStringKey?

    init(title: LocalizedStringKey, info: LocalizedStringKey? = nil) {
        self.init(title: Text(title), info: info)
    }

    init(title: Text, info: LocalizedStringKey? = nil) {
        self.title = title
        self.info = info
    }

    var body: some View {
        HStack(spacing: tokens.space(.titleInfoGap)) {
            title
                .font(tokens.font(.sectionHeader))
                .foregroundStyle(tokens.color(.tertiaryText))
            if let info { InfoButton(text: info, tint: tokens.color(.tertiaryText)) }
        }
        .padding(.horizontal, tokens.space(.plateInner))
        .padding(.bottom, tokens.space(.headerToPlate))
    }
}

/// The rounded group background.
struct Plate<Content: View>: View {
    @Environment(\.tokens) private var tokens
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: tokens.space(.plateRowGap)) { content }
            .padding(tokens.space(.plateInner))
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(tokens.color(.plateBackground),
                        in: RoundedRectangle(cornerRadius: tokens.radius(.plate), style: .continuous))
    }
}

/// A row inside a plate: icon column, title with ⓘ right after it, trailing control.
struct PlateRow<Trailing: View>: View {
    @Environment(\.tokens) private var tokens
    @Environment(\.icons) private var icons
    let icon: Icon?
    let title: Text
    let info: LocalizedStringKey?
    let tint: Color?
    let indent: Bool
    let trailing: Trailing

    init(icon: Icon?, title: LocalizedStringKey, info: LocalizedStringKey? = nil, tint: Color? = nil, indent: Bool = false,
         @ViewBuilder trailing: () -> Trailing) {
        self.init(icon: icon, title: Text(title), info: info, tint: tint, indent: indent, trailing: trailing)
    }

    /// A title already made into text, e.g. `Text(verbatim:)` for a note's name.
    init(icon: Icon?, title: Text, info: LocalizedStringKey? = nil, tint: Color? = nil, indent: Bool = false,
         @ViewBuilder trailing: () -> Trailing) {
        self.icon = icon
        self.title = title
        self.info = info
        self.tint = tint
        self.indent = indent
        self.trailing = trailing()
    }

    /// One line when the title and the control fit side by side; on narrow screens (iPhone mini) the
    /// control moves under the title instead of squeezing either of them.
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
    }

    private var label: some View {
        HStack(spacing: tokens.space(.iconTextGap)) {
            if let icon {
                Image(icon: icon, icons: icons)
                    .renderingMode(.template)
                    .foregroundStyle(tint ?? tokens.color(.accent))
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
