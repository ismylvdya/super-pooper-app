import SwiftUI

struct SettingsFooter: View {
    @Environment(\.tokens) private var tokens

    var body: some View {
        VStack(spacing: tokens.space(.footerLineGap)) {
            Text(L10n.format("settings.version", Bundle.main.marketingVersion, Bundle.main.buildNumber))
            Text("settings.credits")
        }
        .font(tokens.font(.footer))
        .foregroundStyle(tokens.color(.secondaryText))
        .frame(maxWidth: .infinity)
        .padding(.top, tokens.space(.groupGap))
    }
}

extension Bundle {
    var marketingVersion: String { object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "?" }
    var buildNumber: String { object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "?" }
}
