import AppIntents

/// Connects intents to the app model without the shared code knowing the app.
@MainActor
enum AppActionBridge {
    static var syncHandler: (() async -> Void)?
    static var habitTapHandler: ((String) async -> Void)?

    static func sync() async {
        await syncHandler?()
    }

    static func tapHabit(_ name: String) async {
        await habitTapHandler?(name)
    }
}
