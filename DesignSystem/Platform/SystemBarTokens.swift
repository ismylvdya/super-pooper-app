import SwiftUI

/// The system bars' look the app copies where it draws a bar of its own (lying sideways: the tab bar along the physical
/// bottom, Today's bar buttons in bubbles along the physical top) or sizes a glyph to stand with the system's tab symbols
/// (`TabIconImage`). All of it is `tokens.json` → `systemBar`, so a system look that changes (iOS 26) is matched there.
struct SystemBarTokens: Decodable, Sendable {
    let metric: TokenTable<SystemBarMetric, Double>
    let font: TokenTable<SystemBarFont, FontSpec>

    private enum CodingKeys: String, CodingKey { case metric, font }

    init(from decoder: Decoder) throws {
        try decoder.rejectUnknownKeys(CodingKeys.self)
        let container = try decoder.container(keyedBy: CodingKeys.self)
        metric = try container.decode(TokenTable<SystemBarMetric, Double>.self, forKey: .metric)
        font = try container.decode(TokenTable<SystemBarFont, FontSpec>.self, forKey: .font)
    }
}

/// `systemBar.metric`: sizes and gaps of the system bars.
enum SystemBarMetric: String, CaseIterable, Sendable {
    /// The tab bar lying sideways: its width, the inset of its tabs and how far it stands from the screen edges.
    case landscapeTabBarWidth, tabBarInner, landscapeBarInset
    /// Between a tab's symbol and its label.
    case tabIconLabelGap
    /// A bar button in its bubble, the gap between the buttons of a bubble and the bubbles' inset from the screen sides.
    case barButton, barButtonGap, barSideInset
}

/// `systemBar.font`: a tab's symbol lying sideways (`tabIcon`) and upright in the system tab bar (`systemTabIcon`, only
/// for sizing a hand-drawn glyph), a tab's label lying sideways. The system tab bar keeps its labels at one size whatever
/// the text size, and so does the label lying sideways (`"fixed": true`).
enum SystemBarFont: String, CaseIterable, Sendable {
    case tabIcon, systemTabIcon, tabLabel
}
