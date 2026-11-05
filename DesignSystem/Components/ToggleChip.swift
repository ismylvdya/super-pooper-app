import SwiftUI

/// A chip that is a switch. On a page (`.large`): icon and title, then any values it shows (each its own text), tinted
/// with a tinted fill when on, grey on the plates' color when off; with neither title nor values it is a circle round
/// its icon. In a row of chips on a plate (`.standard`, the review): the icon only, like the chips beside it, tinted
/// when on. The caller plays the tap's haptic.
struct ToggleChip: View {
    @Environment(\.tokens) private var tokens
    let icon: Icon
    var title: LocalizedStringKey?
    var values: [String] = []
    let tint: ColorToken
    let isOn: Bool
    var capsule = ChipCapsule.large
    /// The chip may be narrower than its title, which then dissolves at the right instead of ending with "…".
    var fadesTitle = false
    /// A long press does this; the chip then takes its touches itself, as a button would hold on to them.
    var onLongPress: (() -> Void)?
    let action: () -> Void

    init(icon: Icon, title: LocalizedStringKey? = nil, values: [String] = [], tint: ColorToken, isOn: Bool,
         capsule: ChipCapsule = .large, fadesTitle: Bool = false, onLongPress: (() -> Void)? = nil, action: @escaping () -> Void) {
        self.icon = icon
        self.title = title
        self.values = values
        self.tint = tint
        self.isOn = isOn
        self.capsule = capsule
        self.fadesTitle = fadesTitle
        self.onLongPress = onLongPress
        self.action = action
    }

    /// A property's chip: its icon and its color (`ChipLook`).
    init(_ look: ChipLook, title: LocalizedStringKey? = nil, isOn: Bool, capsule: ChipCapsule = .large, action: @escaping () -> Void) {
        self.init(icon: look.icon, title: title, tint: look.tint ?? .secondaryText, isOn: isOn, capsule: capsule, action: action)
    }

    var body: some View {
        Group {
            if let onLongPress {
                label
                    .contentShape(Capsule())
                    .onTapGesture(perform: action)
                    .onLongPressGesture(perform: onLongPress)
                    .accessibilityAddTraits(.isButton)
            } else {
                Button(action: action) { label }.buttonStyle(.plain)
            }
        }
        .accessibilityAddTraits(isOn ? .isSelected : [])
    }

    @ViewBuilder private var label: some View {
        switch capsule {
        case .standard:
            Chip(icon: icon, tint: tokens.color(tint), isOn: isOn)
        case .large where title == nil && values.isEmpty:
            IconGlyph(icon, font: .toggleChip)
                .font(tokens.font(.toggleChip))
                .foregroundStyle(foreground)
                .padding(ChipCapsule.large.verticalPadding(tokens))
                .background(fill, in: Capsule())
        case .large:
            HStack(spacing: tokens.space(.chipGap)) {
                IconGlyph(icon, font: .toggleChip)
                if let title { titleText(title) }
                ForEach(values, id: \.self) { Text(verbatim: $0).lineLimit(1) }
            }
            .font(tokens.font(.toggleChip))
            .foregroundStyle(foreground)
            .chipCapsule(fill, .large)
        }
    }

    /// The title in a line of its own width, or one that takes what the chip has left and clips and dissolves there.
    @ViewBuilder private func titleText(_ title: LocalizedStringKey) -> some View {
        if fadesTitle {
            Text(title).lineLimit(1).fixedSize()
                .frame(minWidth: 0, maxWidth: .infinity, alignment: .leading)
                .clipped()
                .mask {
                    HStack(spacing: 0) {
                        Color.black
                        LinearGradient(colors: [.black, .clear], startPoint: .leading, endPoint: .trailing).frame(width: tokens.size(.titleFade))
                    }
                }
        } else {
            Text(title).lineLimit(1)
        }
    }

    private var foreground: Color { isOn ? tokens.color(tint) : tokens.color(.secondaryText) }

    private var fill: Color { isOn ? tokens.color(tint).opacity(tokens.opacity(.toggleChipFill)) : tokens.color(.plateBackground) }
}
