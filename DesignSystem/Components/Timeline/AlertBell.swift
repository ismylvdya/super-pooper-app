import SwiftUI

/// The mark of an event with a Calendar alert (a plain bell in `color`) and of a block that rings as an alarm (`isAlarm`,
/// an alarm clock). Size and, without a color, opacity come from the settings.
struct AlertBell: View {
    @Environment(\.tokens) private var tokens
    @Environment(\.icons) private var icons
    @Environment(\.timelineBell) private var bell
    var color: Color?
    var isAlarm = false

    var body: some View {
        Image(systemName: icons[isAlarm ? .alarm : .bell])
            .resizable()
            .scaledToFit()
            .frame(width: bell.size, height: bell.size)
            .foregroundStyle(color ?? tokens.color(.primaryText).opacity(bell.opacity))
            .accessibilityLabel(Text(isAlarm ? "alarm.title" : "timeline.alert"))
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
