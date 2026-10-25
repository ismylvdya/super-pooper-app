import SwiftUI

/// A settings-style group: header above, rounded plate with rows, hint below (manifest specs).
struct PlateSection<Content: View>: View {
    @Environment(\.tokens) private var tokens
    let header: LocalizedStringKey?
    var info: LocalizedStringKey?
    var hint: LocalizedStringKey?
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if let header { PlateHeader(title: header, info: info) }
            Plate { content }
            if let hint {
                Text(hint)
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
    let title: LocalizedStringKey
    var info: LocalizedStringKey?

    var body: some View {
        HStack(spacing: tokens.space(.titleInfoGap)) {
            Text(title)
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
    let title: LocalizedStringKey
    var info: LocalizedStringKey?
    var tint: Color?
    var indent = false
    @ViewBuilder let trailing: Trailing

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
                Text(title).foregroundStyle(tint ?? tokens.color(.primaryText))
                if let info { InfoButton(text: info, tint: tint ?? tokens.color(.primaryText)) }
            }
        }
    }
}

extension PlateRow where Trailing == EmptyView {
    init(icon: Icon?, title: LocalizedStringKey, info: LocalizedStringKey? = nil, tint: Color? = nil, indent: Bool = false) {
        self.init(icon: icon, title: title, info: info, tint: tint, indent: indent) { EmptyView() }
    }
}
