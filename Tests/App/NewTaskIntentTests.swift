import Foundation
import Testing
@testable import SuperPooperApp

/// "New Task" from Siri, Spotlight, Shortcuts or the Action button: the name typed into the system's prompt becomes a
/// task in the Inbox, or in Soon on the day a date in the name gives; a name a note cannot take creates nothing and
/// says why (.4745).
@MainActor
@Suite(.serialized)
struct NewTaskIntentTests {
    @Test func aNameWithoutADateGoesToTheInboxWithTheNewTaskPageDefaults() async throws {
        let events = RecordingEvents()
        let model = try #require(PreviewModel.make(appEvents: events)).model

        let result = await model.createTask(named: "  Купить молоко ")

        #expect(result == .created("Купить молоко"))
        let note = try #require(model.task(named: "Купить молоко"))
        let defaults = NoteDraft.newTask.note
        #expect(note.status == .inbox)
        #expect(note.due == nil && note.isHighPriority == defaults.isHighPriority && note.feel == defaults.feel)
        #expect(note.projects.isEmpty && note.recurrence == nil)
        #expect(events.sent.last == .created("Купить молоко"))
    }

    /// Wednesday 2026-11-04 11:30: "tomorrow 18:20" is Thursday evening; the words leave the name, the task is in Soon.
    @Test func aNameWithADateGoesToSoonOnThatDayWithoutTheDateWords() async throws {
        let model = try #require(PreviewModel.make(calendar: FixedCalendar(current: TestCalendar.calendar),
                                                   clock: SettableClock(TestCalendar.date("2026-11-04", "11:30")),
                                                   appEvents: RecordingEvents())).model

        #expect(await model.createTask(named: "Dentist tomorrow 18:20") == .created("Dentist"))

        let note = try #require(model.task(named: "Dentist"))
        #expect(note.status == .thisWeek)
        #expect(note.due == TaskDue(day: LocalDate("2026-11-05"), time: LocalTime("18:20")))
    }

    @Test func aNameThatIsOnlyADateStaysTheName() async throws {
        let model = try #require(PreviewModel.make(calendar: FixedCalendar(current: TestCalendar.calendar),
                                                   clock: SettableClock(TestCalendar.date("2026-11-04", "11:30")),
                                                   appEvents: RecordingEvents())).model

        #expect(await model.createTask(named: "tomorrow") == .created("tomorrow"))
        #expect(model.task(named: "tomorrow")?.due == TaskDue(day: LocalDate("2026-11-05")))
    }

    @Test func aNameANoteCannotTakeIsRejectedAndNothingIsWritten() async throws {
        let events = RecordingEvents()
        let model = try #require(PreviewModel.make(appEvents: events)).model
        let before = model.tasks.count

        #expect(await model.createTask(named: "Встреча: Анна") == .rejected(.forbidden(":")))
        #expect(await model.createTask(named: "   ") == .rejected(.empty))
        #expect(await model.createTask(named: "") == .rejected(.empty))

        #expect(model.tasks.count == before)
        #expect(!events.sent.contains { if case .created = $0 { true } else { false } })
    }

    @Test func theReplyNamesTheTaskOrSaysWhyTheNameCannotBeUsed() async throws {
        let model = try #require(PreviewModel.make(appEvents: RecordingEvents())).model

        #expect(await NewTaskResponder.reply(to: "Позвонить маме", model: model)
            == .created(name: "Позвонить маме", inInbox: true))
        #expect(await NewTaskResponder.reply(to: "Позвонить папе tomorrow", model: model)
            == .created(name: "Позвонить папе", inInbox: false))
        #expect(await NewTaskResponder.reply(to: "a/b", model: model)
            == .rejected(reason: NoteNameProblemText.describe(.forbidden("/"), name: "a/b")))
    }

    @Test func theIntentCreatesTheTaskThroughTheApp() async throws {
        let model = try #require(PreviewModel.make(appEvents: RecordingEvents())).model
        AppActionBridge.newTaskHandler = { name in await NewTaskResponder.reply(to: name, model: model) }
        defer { AppActionBridge.newTaskHandler = nil }

        _ = try await NewTaskIntent(name: "Вынести мусор").perform()

        #expect(model.task(named: "Вынести мусор")?.status == .inbox)
    }

    @Test func withoutTheAppTheIntentWritesNothing() async {
        AppActionBridge.newTaskHandler = nil
        #expect(await AppActionBridge.createTask(named: "Вынести мусор") == .unavailable)
    }
}
