import AlarmKit
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

/// The alarm's button: the ringing stops at once, and it rings again after the minutes the settings say, as with Snooze on its
/// notification. Unlike the slider, a custom button stops nothing by itself.
struct AlarmSnoozeIntent: LiveActivityIntent {
    static let title: LocalizedStringResource = "intent.alarmSnooze.title"
    static let isDiscoverable = false
    static let openAppWhenRun = false

    @Parameter(title: "intent.alarm.item") var alarmID: String
    @Parameter(title: "intent.alarm.item") var key: String
    @Parameter(title: "intent.alarm.day") var day: String

    init() {}

    init(alarmID: String, key: String, day: String) {
        self.alarmID = alarmID
        self.key = key
        self.day = day
    }

    func perform() async throws -> some IntentResult {
        stopRinging()
        if let day = LocalDate(isoString: day) { await AppActionBridge.alarmSnooze(key, day) }
        return .result()
    }

    /// This alarm; one set before the button knew its id goes by being the one that rings.
    private func stopRinging() {
        let manager = AlarmManager.shared
        if let id = UUID(uuidString: alarmID) {
            try? manager.stop(id: id)
        } else {
            for alarm in (try? manager.alarms) ?? [] where alarm.state == .alerting { try? manager.stop(id: alarm.id) }
        }
    }
}
