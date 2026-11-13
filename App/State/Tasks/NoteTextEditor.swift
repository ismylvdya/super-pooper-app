import Foundation
import Observation

/// The text of the notes open on their pages: read when the page opens, written shortly after typing stops and when
/// the page closes. The writes of one note run one after another, and the page reads the text again only after them.
@MainActor
@Observable
final class NoteTextEditor {
    private(set) var bodies: [String: NoteBody] = [:]
    @ObservationIgnored private let tasks: TaskState
    @ObservationIgnored private let store: TaskStore
    @ObservationIgnored private let appEvents: AppEventSink
    @ObservationIgnored private let delay: Delay
    @ObservationIgnored private let saveDelay: Double
    /// The write of each note's text waiting for typing to stop, and the writes running.
    @ObservationIgnored private var debounce: [String: Task<Void, Never>] = [:]
    @ObservationIgnored private var saves: [String: Task<Void, Never>] = [:]

    init(tasks: TaskState, store: TaskStore, appEvents: AppEventSink, delay: Delay, saveDelay: Double) {
        self.tasks = tasks
        self.store = store
        self.appEvents = appEvents
        self.delay = delay
        self.saveDelay = saveDelay
    }

    func open(_ name: String) async {
        bodies[name] = .loading
        await saves[name]?.value
        guard let task = tasks.task(named: name) else {
            bodies[name] = .unavailable
            return
        }
        do {
            bodies[name] = .read(try await store.text(of: task))
        } catch {
            SyncLog.logger.error("text of \(name, privacy: .public) unreadable: \(String(describing: error), privacy: .public)")
            bodies[name] = .unavailable
        }
    }

    /// Ignored until the text was read: nothing typed into an unread text is ever written.
    func edit(_ text: String, of name: String) {
        guard var body = bodies[name], body.edit(text) else { return }
        bodies[name] = body
        debounce[name]?.cancel()
        debounce[name] = Task {
            try? await delay.wait(saveDelay)
            guard !Task.isCancelled else { return }
            await save(name)?.value
        }
    }

    /// The page closes: what was typed and not written yet is written now.
    func close(_ name: String) {
        debounce.removeValue(forKey: name)?.cancel()
        save(name)
        bodies[name] = nil
    }

    /// What was typed a moment ago is written before the note is renamed.
    func flush(_ name: String) async {
        debounce.removeValue(forKey: name)?.cancel()
        save(name)
        await saves[name]?.value
    }

    /// Every text typed and not written yet, written now (the app leaves the screen).
    func flushAll() async {
        for name in Array(debounce.keys) { await flush(name) }
    }

    /// Returns when the text typed into the note so far is written (after the pause).
    func waitForTyping(in name: String) async {
        await debounce[name]?.value
    }

    /// A text that could not be read is tried again after every sync (pull to refresh on its page).
    func reopenUnavailable() async {
        for (name, body) in bodies where body.state == .unavailable {
            await open(name)
        }
    }

    @discardableResult
    private func save(_ name: String) -> Task<Void, Never>? {
        guard let body = bodies[name], body.hasUnsavedChanges else { return nil }
        let text = body.text
        let previous = saves[name]
        let save = Task {
            await previous?.value
            if await write(text, of: name) { bodies[name]?.markSaved(text) }
        }
        saves[name] = save
        return save
    }

    private func write(_ text: String, of name: String) async -> Bool {
        guard let task = tasks.task(named: name) else { return false }
        do {
            let result = try await store.setText(text, of: task)
            tasks.written(result.task)
            if let clashes = AppEvent.clashes(in: result, of: task.name) { appEvents.send(clashes) }
            return true
        } catch {
            appEvents.send(.failure(AppFailure(error)))
            return false
        }
    }
}
