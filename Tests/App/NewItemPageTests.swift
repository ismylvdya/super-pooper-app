import Testing
@testable import SuperPooperApp

/// What leaving the new-item page creates. The draft is never lost to a name a note cannot take, and switching
/// between Task and Habit loses neither the name nor what was set for each kind.
struct NewItemPageTests {
    private let unnamed = "Unnamed"
    private let names = ObsidianNoteNames(rules: TestConfig.mapping.obsidian.noteNames)
    private let habitDraft = NoteDraft.newHabit(startingOn: LocalDate("2026-11-04"), showInToday: true, color: "#000000")

    private func taskPage() -> NewItemPage {
        NewItemPage(kind: .task, taskDraft: NoteDraft(status: .thisWeek), habitDraft: habitDraft)
    }

    @Test func switchingKindKeepsTheNameAndEachKindsDraft() {
        var page = taskPage()
        page.name = "Stretch"
        page.draft.apply([.highPriority(true)])
        page.kind = .habit
        #expect(page.name == "Stretch")
        #expect(page.draft == habitDraft)
        page.kind = .task
        #expect(page.draft.changes == [.highPriority(true)])
    }

    @Test func onlyTheShownKindIsCreated() throws {
        var page = taskPage()
        page.name = "Stretch"
        page.kind = .habit
        #expect(try #require(page.savedOnReturn(rules: names.problem(in:))).draft.note.status == .habit)
        #expect(try #require(page.creation(unnamed: unnamed, rules: names.problem(in:))).draft == habitDraft)
    }

    /// A kind switched to and left as it came is untouched, even when the other kind was edited.
    @Test func anUntouchedShownKindCreatesNothingWithoutAName() {
        var page = taskPage()
        page.draft.apply([.highPriority(true)])
        page.kind = .habit
        #expect(page.creation(unnamed: unnamed, rules: names.problem(in:)) == nil)
    }

    @Test func anUntouchedPageCreatesNothing() {
        #expect(taskPage().creation(unnamed: unnamed, rules: names.problem(in:)) == nil)
    }

    @Test func aNameTypedIsTheNoteNameWithoutSpacesAround() throws {
        var page = taskPage()
        page.name = "  Купить хлеб "
        let creation = try #require(page.creation(unnamed: unnamed, rules: names.problem(in:)))
        #expect(creation.name == "Купить хлеб")
        #expect(creation.draft == NoteDraft(status: .thisWeek))
    }

    @Test func aPageWithSomethingSetButNoNameIsUnnamed() throws {
        var page = taskPage()
        page.draft.apply([.highPriority(true)])
        let creation = try #require(page.creation(unnamed: unnamed, rules: names.problem(in:)))
        #expect(creation.name == unnamed)
        #expect(creation.draft.changes == [.highPriority(true)])
    }

    /// The reported loss: "Meet: Anna" was refused only after the page was gone, and the draft with it. Now the name is
    /// checked while typing and nothing is created (the page keeps the draft until the name is changed).
    @Test func aNameANoteCannotTakeIsShownAndCreatesNothing() {
        var page = taskPage()
        page.draft.body = "Повестка"
        page.name = "Meet: Anna"
        #expect(page.nameProblem(names.problem(in:)) == .forbidden(":"))
        #expect(page.creation(unnamed: unnamed, rules: names.problem(in:)) == nil)
        page.name = "Meet Anna"
        #expect(page.nameProblem(names.problem(in:)) == nil)
        #expect(page.creation(unnamed: unnamed, rules: names.problem(in:))?.draft.body == "Повестка")
    }

    /// Return in the name saves the note at once under the typed name; an empty name only closes the keyboard, a name a
    /// note cannot take keeps the draft (.1571).
    @Test func returnSavesOnlyANameANoteCanTake() throws {
        var page = taskPage()
        page.draft.apply([.highPriority(true)])
        #expect(page.savedOnReturn(rules: names.problem(in:)) == nil)
        page.name = "Meet: Anna"
        #expect(page.savedOnReturn(rules: names.problem(in:)) == nil)
        page.name = " Meet Anna "
        let saving = try #require(page.savedOnReturn(rules: names.problem(in:)))
        #expect(saving.name == "Meet Anna")
        #expect(saving.draft.changes == [.highPriority(true)])
    }
}
