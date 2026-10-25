import SwiftUI

/// The end of a row that opens a page: an optional grey value, then the chevron.
struct DisclosureAccessory: View {
    @Environment(\.tokens) private var tokens
    @Environment(\.icons) private var icons
    var value: String?

    var body: some View {
        HStack(spacing: tokens.space(.valueChevronGap)) {
            if let value { Text(verbatim: value).foregroundStyle(tokens.color(.secondaryText)) }
            Image(systemName: icons[.chevron]).foregroundStyle(tokens.color(.tertiaryText))
        }
    }
}
