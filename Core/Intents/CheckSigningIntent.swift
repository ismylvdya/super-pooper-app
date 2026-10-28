import AppIntents

/// "Check App Signature" for Shortcuts: when the app's signature runs out within the warning time, a notification
/// says so right away (re-sign the app, turn the Calendar and Reminders notifications back on). Meant for a daily
/// personal automation; it runs in the app's process without opening it.
struct CheckSigningIntent: AppIntent {
    static let title: LocalizedStringResource = "intent.signing.title"
    static let description = IntentDescription("intent.signing.description")
    static let openAppWhenRun = false

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let expiration = await AppActionBridge.checkSigning()
        guard let expiration else { return .result(dialog: "intent.signing.unknown") }
        return .result(dialog: "intent.signing.until \(expiration.formatted(date: .abbreviated, time: .shortened))")
    }
}
