import Testing
@testable import SuperPooperApp

/// Names Obsidian can give a note file, and what is wrong with the others.
struct NoteNameRulesTests {
    @Test func ordinaryNamesAreValid() {
        #expect(NoteNameRules.isValid("Позвонить в банк 🏦"))
        #expect(NoteNameRules.problem(in: "Read 20 min.") == nil)
    }

    @Test func eachProblemIsNamed() {
        #expect(NoteNameRules.problem(in: "  ") == .empty)
        #expect(NoteNameRules.problem(in: " Call") == .spacesAround)
        #expect(NoteNameRules.problem(in: ".hidden") == .leadingDot)
        #expect(NoteNameRules.problem(in: "Meet: Anna") == .forbidden(":"))
        #expect(NoteNameRules.problem(in: "a/b#c") == .forbidden("/"))
        #expect(NoteNameRules.problem(in: String(repeating: "a", count: NoteNameRules.maxLength + 1))
                == .tooLong(limit: NoteNameRules.maxLength))
        #expect(!NoteNameRules.isValid("[[Link]]"))
    }
}
