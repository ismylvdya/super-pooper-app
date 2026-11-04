import AppIntents

/// Connects intents to the app model without the shared code knowing the app.
@MainActor
enum AppActionBridge {
    static var syncHandler: (() async -> Void)?
    static var habitTapHandler: ((String) async -> Void)?
    /// Warns now if the signature runs out soon; the expiration, nil when the app has none.
    static var signingCheckHandler: (() async -> Date?)?

    /// An alarm's slider and Snooze button.
    static var alarmDoneHandler: ((String, LocalDate?) async -> Void)?
    static var alarmSnoozeHandler: ((String, LocalDate) async -> Void)?

    static func alarmDone(_ name: String, _ day: LocalDate?) async { await alarmDoneHandler?(name, day) }
    static func alarmSnooze(_ key: String, _ day: LocalDate) async { await alarmSnoozeHandler?(key, day) }

    static func sync() async {
        await syncHandler?()
    }

    static func tapHabit(_ name: String) async {
        await habitTapHandler?(name)
    }

    static func checkSigning() async -> Date? {
        await signingCheckHandler?()
    }
}
