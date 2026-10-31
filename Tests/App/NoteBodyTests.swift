import Foundation
import Testing
@testable import SuperPooperApp

/// The text of a note on its page: a text that could not be read is never written over, what was typed is written
/// once typing stops and when the page closes.
@MainActor
struct NoteBodyTests {
    private let name = "Сдать отчёт"

    private func make(delay: Delay = NoDelay()) throws -> (model: AppModel, repository: InMemoryTaskStore) {
        let model = try #require(PreviewModel.make(delay: delay)).model
        return (model, try #require(model.services.tasks as? InMemoryTaskStore))
    }

    /// The reported data loss: a text not downloaded (or with broken YAML) showed as an empty field, and the first
    /// keystroke wrote that field over the real text.
    @Test func aTextThatCannotBeReadIsNeverWrittenOver() async throws {
        let (model, repository) = try make()
        await repository.setBodyReadable(false, of: name)
        await model.openBody(of: name)
        #expect(model.noteBodies[name]?.state == .unavailable)

        model.editBody("x", of: name)
        #expect(model.noteBodies[name]?.text == "")
        model.closeBody(of: name)
        await model.flushBody(of: name)
        #expect(await repository.bodyWrites.isEmpty)
    }

    /// Pull to refresh on the page reads a text that could not be read before.
    @Test func anUnreadableTextIsReadAgainAfterASync() async throws {
        let (model, repository) = try make()
        await repository.setBodyReadable(false, of: name)
        await model.openBody(of: name)
        await repository.setBodyReadable(true, of: name)
        await model.sync(announce: true)
        #expect(model.noteBodies[name] == .read("Заметка к задаче."))
    }

    @Test func typingIsWrittenOnceWhenItStops() async throws {
        let delay = GatedDelay()
        let (model, repository) = try make(delay: delay)
        await model.openBody(of: name)
        model.editBody("Н", of: name)
        model.editBody("Новый текст", of: name)
        await delay.gate.arrived(2)
        await delay.gate.open()
        await model.noteBodyDebounce[name]?.value
        #expect(await repository.bodyWrites == ["Новый текст"])
        #expect(model.noteBodies[name]?.hasUnsavedChanges == false)
    }

    /// Leaving the page before the pause is over writes the text at once; the page opened again reads it back.
    @Test func closingThePageWritesWhatWasTyped() async throws {
        let (model, repository) = try make(delay: GatedDelay())
        await model.openBody(of: name)
        model.editBody("Дописано", of: name)
        model.closeBody(of: name)
        #expect(model.noteBodies[name] == nil)
        await model.openBody(of: name)
        #expect(model.noteBodies[name] == .read("Дописано"))
        #expect(await repository.bodyWrites == ["Дописано"])
    }

    /// A rename right after typing does not lose the text: it is written under the old name first.
    @Test func aRenameWritesTheTypedTextFirst() async throws {
        let (model, repository) = try make(delay: GatedDelay())
        await model.openBody(of: name)
        model.editBody("Перед переименованием", of: name)
        #expect(await model.rename(name, to: "Отчёт сдан"))
        #expect(await repository.bodyWrites == ["Перед переименованием"])
    }
}
