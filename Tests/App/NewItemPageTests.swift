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

/// A date typed into a new task's name is offered in blue; a tap on it sets the date and takes its words out.
struct NewItemDateSuggestionTests {
    private let names = ObsidianNoteNames(rules: TestConfig.mapping.obsidian.noteNames)
    private let detector = DateDetector(grammar: TestConfig.dateGrammar)
    private let wednesday = TestCalendar.context("2026-11-04", "11:30")

    private func taskPage(named name: String) -> NewItemPage {
        var page = NewItemPage(kind: .task, taskDraft: NoteDraft(status: .thisWeek),
                               habitDraft: NoteDraft.newHabit(startingOn: LocalDate("2026-11-04"), showInToday: true, color: "#000000"))
        page.name = name
        return page
    }

    @Test func acceptingADateSetsItAndTakesTheWordsOut() throws {
        var page = taskPage(named: "Dentist tomorrow 18:20")
        let found = try #require(detector.detect(in: page.name, context: wednesday))
        page.accept(found)
        #expect(page.name == "Dentist")
        #expect(page.draft.note.due == TaskDue(day: LocalDate("2026-11-05"), time: LocalTime("18:20")))
    }

    @Test func acceptingTheWholeNameKeepsItAsTheName() throws {
        var page = taskPage(named: "tomorrow")
        page.accept(try #require(detector.detect(in: page.name, context: wednesday)))
        #expect(page.name == "tomorrow")
        #expect(page.draft.note.due?.day == LocalDate("2026-11-05"))
    }

    /// The blue is a suggestion: Return without a tap saves the task undated.
    @Test func aSuggestionNotTappedIsNotSaved() throws {
        let page = taskPage(named: "Dentist tomorrow")
        let saved = try #require(page.savedOnReturn(rules: names.problem(in:)))
        #expect(saved.draft.note.due == nil)
        #expect(saved.name == "Dentist tomorrow")
    }


    /// A habit is not dated, and a date the task already has is not offered again.
    @Test func onlyATaskIsOfferedADateItDoesNotHave() throws {
        var page = taskPage(named: "tomorrow")
        let found = try #require(detector.detect(in: page.name, context: wednesday))
        #expect(page.suggestion(found) == found)
        page.accept(found)
        #expect(page.suggestion(found) == nil)
        var habit = taskPage(named: "Stretch tomorrow")
        habit.kind = .habit
        #expect(habit.suggestion(detector.detect(in: habit.name, context: wednesday)) == nil)
    }
}
