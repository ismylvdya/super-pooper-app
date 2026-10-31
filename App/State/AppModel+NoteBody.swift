import Foundation

/// The text of a note, edited on its page: read when the page opens, written shortly after typing stops and when the
/// page closes. The writes of one note run one after another, and the page reads the text again only after them.
extension AppModel {
    func openBody(of name: String) async {
        noteBodies[name] = .loading
        await noteBodySaves[name]?.value
        guard let task = task(named: name) else {
            noteBodies[name] = .unavailable
            return
        }
        do {
            noteBodies[name] = .read(try await services.tasks.body(of: task))
        } catch {
            SyncLog.logger.error("text of \(name, privacy: .public) unreadable: \(String(describing: error), privacy: .public)")
            noteBodies[name] = .unavailable
        }
    }

    /// Ignored until the text was read: nothing typed into an unread text is ever written.
    func editBody(_ text: String, of name: String) {
        guard var body = noteBodies[name], body.edit(text) else { return }
        noteBodies[name] = body
        noteBodyDebounce[name]?.cancel()
        noteBodyDebounce[name] = Task {
            try? await delay.wait(config.rules.editing.noteSaveDelaySeconds)
            guard !Task.isCancelled else { return }
            await saveBody(of: name)?.value
        }
    }

    /// The page closes: what was typed and not written yet is written now.
    func closeBody(of name: String) {
        noteBodyDebounce.removeValue(forKey: name)?.cancel()
        saveBody(of: name)
        noteBodies[name] = nil
    }

    /// What was typed a moment ago is written before the note is renamed.
    func flushBody(of name: String) async {
        noteBodyDebounce.removeValue(forKey: name)?.cancel()
        saveBody(of: name)
        await noteBodySaves[name]?.value
    }

    /// A text that could not be read is tried again after every sync (pull to refresh on its page).
    func reopenUnavailableBodies() async {
        for (name, body) in noteBodies where body.state == .unavailable {
            await openBody(of: name)
        }
    }

    @discardableResult
    private func saveBody(of name: String) -> Task<Void, Never>? {
        guard let body = noteBodies[name], body.hasUnsavedChanges else { return nil }
        let text = body.text
        let previous = noteBodySaves[name]
        let save = Task {
            await previous?.value
            if await setBody(text, of: name) { noteBodies[name]?.markSaved(text) }
        }
        noteBodySaves[name] = save
        return save
    }

    @discardableResult
    func setBody(_ body: String, of name: String) async -> Bool {
        guard let task = task(named: name) else { return false }
        do {
            let result = try await services.tasks.setBody(body, of: task)
            noteWrite(result.task)
            replace(result.task)
            reportClashes(result, name: task.name)
            return true
        } catch {
            banners.show(Self.describe(error), style: .problem)
            return false
        }
    }
}
