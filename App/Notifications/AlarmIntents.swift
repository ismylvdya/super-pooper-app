import AppIntents
import Foundation

/// The alarm's slider: it stops ringing and leaves the item's notification, with Done on it; the item stays open.
struct AlarmStopIntent: LiveActivityIntent {
    static let title: LocalizedStringResource = "intent.alarmDone.title"
    static let isDiscoverable = false
    static let openAppWhenRun = false

    @Parameter(title: "intent.alarm.item") var key: String
    @Parameter(title: "intent.alarm.day") var day: String

    init() {}

    init(key: String, day: String) {
        self.key = key
        self.day = day
    }

    func perform() async throws -> some IntentResult {
        if let day = LocalDate(isoString: day) { await AppActionBridge.alarmStop(key, day) }
        return .result()
    }
}

/// The alarm's button: it rings again after the minutes the settings say, as with Snooze on its notification.
struct AlarmSnoozeIntent: LiveActivityIntent {
    static let title: LocalizedStringResource = "intent.alarmSnooze.title"
    static let isDiscoverable = false
    static let openAppWhenRun = false

    @Parameter(title: "intent.alarm.item") var key: String
    @Parameter(title: "intent.alarm.day") var day: String

    init() {}

    init(key: String, day: String) {
        self.key = key
        self.day = day
    }

    func perform() async throws -> some IntentResult {
        if let day = LocalDate(isoString: day) { await AppActionBridge.alarmSnooze(key, day) }
        return .result()
    }
}
