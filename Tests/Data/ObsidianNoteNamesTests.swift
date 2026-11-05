import Testing
@testable import SuperPooperApp

/// Names Obsidian can give a note file, and what is wrong with the others.
struct NoteNameRulesTests {
    private let names = ObsidianNoteNames(rules: TestConfig.obsidian.noteNames)

    @Test func ordinaryNamesAreValid() {
        #expect(names.isValid("Позвонить в банк 🏦"))
        #expect(names.problem(in: "Read 20 min.") == nil)
    }

    @Test func eachProblemIsNamed() {
        #expect(names.problem(in: "  ") == .empty)
        #expect(names.problem(in: " Call") == .spacesAround)
        #expect(names.problem(in: ".hidden") == .leadingDot)
        #expect(names.problem(in: "Meet: Anna") == .forbidden(":"))
        #expect(names.problem(in: "a/b#c") == .forbidden("/"))
        #expect(names.problem(in: String(repeating: "a", count: names.rules.maxLength + 1))
                == .tooLong(limit: names.rules.maxLength))
        #expect(!names.isValid("[[Link]]"))
    }
}
