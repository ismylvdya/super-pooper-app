import AppIntents

/// Checks or unchecks a task from a widget checkbox. As a `LiveActivityIntent` it runs in the
/// app's process (the widget cannot open the vault); the app installs the handler at launch,
/// writes the note and reloads the widgets.
struct ToggleTaskIntent: LiveActivityIntent {
    static let title: LocalizedStringResource = "widget.toggle.title"
    static let isDiscoverable = false

    @Parameter(title: "widget.toggle.task")
    var taskName: String

    init() {}

    init(taskName: String) { self.taskName = taskName }

    func perform() async throws -> some IntentResult {
        await WidgetActionBridge.toggle(taskName)
        return .result()
    }
}

/// Connects widget intents to the app model without the shared code knowing the app.
@MainActor
enum WidgetActionBridge {
    static var toggleHandler: ((String) async -> Void)?

    static func toggle(_ taskName: String) async {
        await toggleHandler?(taskName)
    }
}
