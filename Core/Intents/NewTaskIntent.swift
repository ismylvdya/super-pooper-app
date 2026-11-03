import AppIntents

/// "New Task" for Siri, Spotlight, Shortcuts and the Action button: the system asks for the name in its own prompt over
/// whatever is on screen, the app writes the task in the Inbox (in Soon on the day a date in the name gives), and the
/// system's dialog says what happened. It runs in the app's process without opening it; the app installs the handler at launch.
struct NewTaskIntent: AppIntent {
    static let title: LocalizedStringResource = "intent.newTask.title"
    static let description = IntentDescription("intent.newTask.description")
    static let openAppWhenRun = false

    @Parameter(title: "intent.newTask.name", requestValueDialog: "intent.newTask.prompt")
    var name: String

    init() {}

    init(name: String) { self.name = name }

    func perform() async throws -> some IntentResult & ProvidesDialog {
        .result(dialog: Self.dialog(for: await AppActionBridge.createTask(named: name)))
    }

    private static func dialog(for reply: NewTaskReply) -> IntentDialog {
        switch reply {
        case .created(let name, inInbox: true): "intent.newTask.createdInInbox \(name)"
        case .created(let name, inInbox: false): "intent.newTask.created \(name)"
        case .rejected(let reason): "intent.newTask.rejected \(reason)"
        case .failed: "intent.newTask.failed"
        case .unavailable: "intent.newTask.unavailable"
        }
    }
}
