import AppIntents

/// Connects intents to the app model without the shared code knowing the app.
@MainActor
enum AppActionBridge {
    static var syncHandler: (() async -> Void)?
    static var habitTapHandler: ((String) async -> Void)?
    /// Warns now if the signature runs out soon; the expiration, nil when the app has none.
    static var signingCheckHandler: (() async -> Date?)?

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
