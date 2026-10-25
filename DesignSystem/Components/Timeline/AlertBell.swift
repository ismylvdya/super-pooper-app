import SwiftUI

/// The mark of a timeline block that will send a notification: a plain bell in the text color, faded.
/// Size and opacity come from the settings.
struct AlertBell: View {
    @Environment(\.tokens) private var tokens
    @Environment(\.icons) private var icons
    @Environment(\.timelineBell) private var bell

    var body: some View {
        Image(systemName: icons[.bell])
            .resizable()
            .scaledToFit()
            .frame(width: bell.size, height: bell.size)
            .foregroundStyle(tokens.color(.primaryText).opacity(bell.opacity))
            .accessibilityLabel(Text("timeline.alert"))
    }
}

/// Bell size and opacity from the settings.
struct TimelineBellStyle: Equatable {
    var size: CGFloat
    var opacity: Double
}

private struct TimelineBellKey: EnvironmentKey {
    static let defaultValue = BundledConfig.settings.timeline.bellStyle
}

extension EnvironmentValues {
    var timelineBell: TimelineBellStyle {
        get { self[TimelineBellKey.self] }
        set { self[TimelineBellKey.self] = newValue }
    }
}

extension AppSettings.Timeline {
    var bellStyle: TimelineBellStyle { TimelineBellStyle(size: bellSize, opacity: bellOpacity) }
}
