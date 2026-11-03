import SwiftUI

/// The one section title of the app: above a settings plate, a list group, a pool section; grey, a little right of the
/// plates' left edge, with an optional ⓘ.
struct SectionHeader: View {
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
                .foregroundStyle(tokens.color(.sectionHeader))
            if let info { InfoButton(text: info, tint: tokens.color(.sectionHeader)) }
        }
        .padding(.horizontal, tokens.space(.sectionHeaderInset))
        .padding(.bottom, tokens.space(.headerToPlate))
    }
}
