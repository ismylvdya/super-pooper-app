import Testing
@testable import SuperPooperApp

/// What leaving the new task page creates. The draft is never lost to a name a note cannot take.
struct NewNotePageTests {
    private let unnamed = "Unnamed"

    @Test func anUntouchedPageCreatesNothing() {
        #expect(NewNotePage(draft: NoteDraft(status: .thisWeek)).creation(unnamed: unnamed) == nil)
    }

    @Test func aNameTypedIsTheNoteNameWithoutSpacesAround() throws {
        var page = NewNotePage(draft: NoteDraft(status: .thisWeek))
        page.name = "  Купить хлеб "
        let creation = try #require(page.creation(unnamed: unnamed))
        #expect(creation.name == "Купить хлеб")
        #expect(creation.draft == NoteDraft(status: .thisWeek))
    }

    @Test func aPageWithSomethingSetButNoNameIsUnnamed() throws {
        var page = NewNotePage(draft: NoteDraft(status: .thisWeek))
        page.draft.apply([.highPriority(true)])
        let creation = try #require(page.creation(unnamed: unnamed))
        #expect(creation.name == unnamed)
        #expect(creation.draft.changes == [.highPriority(true)])
    }

    /// The reported loss: "Meet: Anna" was refused only after the page was gone, and the draft with it. Now the name is
    /// checked while typing and nothing is created (the page keeps the draft until the name is changed).
    @Test func aNameANoteCannotTakeIsShownAndCreatesNothing() {
        var page = NewNotePage(draft: NoteDraft(status: .thisWeek))
        page.draft.body = "Повестка"
        page.name = "Meet: Anna"
        #expect(page.nameProblem == .forbidden(":"))
        #expect(page.creation(unnamed: unnamed) == nil)
        page.name = "Meet Anna"
        #expect(page.nameProblem == nil)
        #expect(page.creation(unnamed: unnamed)?.draft.body == "Повестка")
    }
}
