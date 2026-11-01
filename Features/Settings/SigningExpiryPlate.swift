import SwiftUI

/// At the top of Settings while the app's signature runs out soon: how long it has left, on a plate tinted by how close
/// the end is (green, yellow, red: `SigningCountdown.Level`), and under it what to do about it.
struct SigningExpiryPlate: View {
    @Environment(\.tokens) private var tokens
    let countdown: SigningCountdown

    var body: some View {
        let color = tokens.color(countdown.level.color)
        VStack(alignment: .leading, spacing: 0) {
            PlateRow(icon: .signing, title: "settings.signing.title", iconTint: color) {
                Text(verbatim: SigningCountdownText.remaining(countdown.remaining)).bold()
            }
            .padding(tokens.space(.plateInner))
            .frame(maxWidth: .infinity, alignment: .leading)
            .plate(.group, fill: color.opacity(tokens.opacity(.signingPlate)))
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("settings.signing")
            PlateHint(text: Text("settings.signing.hint"))
        }
    }
}

extension SigningCountdown.Level {
    var color: ColorToken {
        switch self {
        case .ahead: .signingAhead
        case .soon: .signingSoon
        case .urgent: .signingUrgent
        }
    }
}
