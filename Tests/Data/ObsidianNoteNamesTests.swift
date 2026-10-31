import Testing
@testable import SuperPooperApp

/// Names Obsidian can give a note file, and what is wrong with the others.
struct NoteNameRulesTests {
    @Test func ordinaryNamesAreValid() {
        #expect(ObsidianNoteNames.isValid("Позвонить в банк 🏦"))
        #expect(ObsidianNoteNames.problem(in: "Read 20 min.") == nil)
    }

    @Test func eachProblemIsNamed() {
        #expect(ObsidianNoteNames.problem(in: "  ") == .empty)
        #expect(ObsidianNoteNames.problem(in: " Call") == .spacesAround)
        #expect(ObsidianNoteNames.problem(in: ".hidden") == .leadingDot)
        #expect(ObsidianNoteNames.problem(in: "Meet: Anna") == .forbidden(":"))
        #expect(ObsidianNoteNames.problem(in: "a/b#c") == .forbidden("/"))
        #expect(ObsidianNoteNames.problem(in: String(repeating: "a", count: ObsidianNoteNames.maxLength + 1))
                == .tooLong(limit: ObsidianNoteNames.maxLength))
        #expect(!ObsidianNoteNames.isValid("[[Link]]"))
    }
}
