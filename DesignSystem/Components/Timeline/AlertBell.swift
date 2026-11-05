import SwiftUI

/// The mark of an event with a Calendar alert (a plain bell in `color`) and of a block that rings as an alarm (`isAlarm`,
/// an alarm clock). Size and, without a color, opacity come from the settings.
struct AlertBell: View {
    @Environment(\.tokens) private var tokens
    @Environment(\.icons) private var icons
    @Environment(\.timelineBell) private var bell
    var color: Color?
    var isAlarm = false
    /// An alarm mark as big as the bells beside it (a widget's timeline).
    var sizedAsBell = false

    var body: some View {
        Image(systemName: icons[isAlarm ? .alarm : .bell])
            .resizable()
            .scaledToFit()
            .frame(width: size, height: size)
            .foregroundStyle(color ?? tokens.color(.primaryText).opacity(bell.opacity))
            .accessibilityLabel(Text(isAlarm ? "alarm.title" : "timeline.alert"))
    }

    private var size: CGFloat { isAlarm && !sizedAsBell ? tokens.size(.alarmMark) : bell.size }
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
