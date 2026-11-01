import SwiftUI

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
