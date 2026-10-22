import Foundation
import Testing
@testable import SuperPooper

private enum Notes {
    /// Frontmatter of a typical TaskNotes note plus unknown keys, comments, blank lines and a block scalar.
    static let richFrontmatter = #"""
    ---
    # Task note managed by TaskNotes
    tags:
      - 🔫делишка
      - "#дом"
    status: this_week
    priority: high # important

    due: 2026-10-23T16:00
    time_estimate: 15
    previous_task:
      - uid: "[[Купить батарейки]]"
        reltype: FINISHTOSTART
    previous_event: "8A1F…:A2B3…|Call with dad|2026-10-23T19:00:00+02:00"
    need_energy: true
    pleasant: false
    recurrence: DTSTART:20261001T090000Z;FREQ=DAILY
    recurrence_anchor: scheduled
    complete_instances:
      - 2026-10-20
      - 2026-10-21
    contexts: [home, "errands, city", 'it''s']
    custom_plugin:
      nested:
        depth: 2
        note: "escaped \"quote\" and \\ backslash"
      flag: yes
    notes: |
      Первая строка
        с отступом

      после пустой строки 😀
    # comment after the block scalar
    date_created: 2026-10-20T09:12:44.123+02:00
    ---

    """#

    static let richFrontmatterWithStatusDone = #"""
    ---
    # Task note managed by TaskNotes
    tags:
      - 🔫делишка
      - "#дом"
    status: done
    priority: high # important

    due: 2026-10-23T16:00
    time_estimate: 15
    previous_task:
      - uid: "[[Купить батарейки]]"
        reltype: FINISHTOSTART
    previous_event: "8A1F…:A2B3…|Call with dad|2026-10-23T19:00:00+02:00"
    need_energy: true
    pleasant: false
    recurrence: DTSTART:20261001T090000Z;FREQ=DAILY
    recurrence_anchor: scheduled
    complete_instances:
      - 2026-10-20
      - 2026-10-21
    contexts: [home, "errands, city", 'it''s']
    custom_plugin:
      nested:
        depth: 2
        note: "escaped \"quote\" and \\ backslash"
      flag: yes
    notes: |
      Первая строка
        с отступом

      после пустой строки 😀
    # comment after the block scalar
    date_created: 2026-10-20T09:12:44.123+02:00
    ---

    """#

    static let body = #"""
    # Заголовок 📝

    Body text (markdown) with a horizontal rule and things that look like YAML:

    ---

    status: not frontmatter
    tags: [also, not, frontmatter]

    ```yaml
    ---
    key: value
    ---
    ```

    | Колонка | Column |
    |---------|--------|
    | 🔫      | 💥     |

    - [ ] checklist item
    - [x] done item with [[Wiki link]] and `code: here`
    ---
    Last line without a line break
    """#

    static let rich = richFrontmatter + body
    static let richWithStatusDone = richFrontmatterWithStatusDone + body

    static let habit = """
    ---
    tags:
    - 🔫делишка
    status: half_year
    due: 2026-10-01T09:00
    recurrence: DTSTART:20261001T090000Z;FREQ=DAILY
    complete_instances: []
    ---

    """

    static let validSamples: [String] = [
        rich,
        rich.replacingOccurrences(of: "\n", with: "\r\n"),
        "\u{FEFF}" + rich,
        habit,
        "---\n---\n",
        "---\n---",
        "---   \nstatus: open\n...  \nbody\n",
        "---\n# only a comment\n\n---\nbody with и\u{0306} decomposed\n",
        "---\ntitle: \"Сло\u{0306}во\"\n---\n",
        "---\n\"quoted key\": 'value'\n---\n",
    ]
}

struct FrontmatterTests {
    // MARK: - Byte-for-byte editing

    @Test func settingScalarKeepsEveryOtherByte() throws {
        var document = try FrontmatterDocument(text: Notes.rich)
        document.set("status", to: .string("done"))
        expectSameBytes(document.text, Notes.richWithStatusDone)
    }

    @Test func settingListKeepsEveryOtherByte() throws {
        var document = try FrontmatterDocument(text: Notes.rich)
        document.set("complete_instances", to: .list(["2026-10-20", "2026-10-21", "2026-10-22"].map { YAMLValue.string($0) }))
        let expected = Notes.rich.replacingOccurrences(of: "  - 2026-10-21\n", with: "  - 2026-10-21\n  - 2026-10-22\n")
        expectSameBytes(document.text, expected)
    }

    @Test func crlfFilesStayCRLF() throws {
        let crlf = Notes.rich.replacingOccurrences(of: "\n", with: "\r\n")
        var document = try FrontmatterDocument(text: crlf)
        document.set("status", to: .string("done"))
        document.set("date_modified", to: .string("2026-10-23T10:00:00.000+02:00"))

        let expected = Notes.richWithStatusDone
            .replacingOccurrences(of: "+02:00\n---\n#", with: "+02:00\ndate_modified: 2026-10-23T10:00:00.000+02:00\n---\n#")
            .replacingOccurrences(of: "\n", with: "\r\n")
        expectSameBytes(document.text, expected)
        #expect(!document.text.replacingOccurrences(of: "\r\n", with: "").contains("\n"))
    }

    @Test func byteOrderMarkIsPreserved() throws {
        var document = try FrontmatterDocument(text: "\u{FEFF}" + Notes.rich)
        #expect(try document.value(for: "status") == .scalar("this_week", quoted: false))
        document.set("status", to: .string("done"))
        expectSameBytes(document.text, "\u{FEFF}" + Notes.richWithStatusDone)
    }

    @Test func appendsMissingKeyAtEndOfFrontmatter() throws {
        var document = try FrontmatterDocument(text: "---\nstatus: open\n# closing comment\n\n---\nBody\n")
        document.set("priority", to: .string("high"))
        expectSameBytes(document.text, "---\nstatus: open\n# closing comment\n\npriority: high\n---\nBody\n")

        var empty = try FrontmatterDocument(text: "---\n---\n")
        empty.set("tags", to: .list([.string("🔫делишка")]))
        expectSameBytes(empty.text, "---\ntags:\n  - 🔫делишка\n---\n")
    }

    @Test func removingKeysKeepsSurroundingLines() throws {
        let original = """
        ---
        tags:
          - a
        # about status
        status: open

        complete_instances:
          - 2026-10-20
          - 2026-10-21

        # trailing
        due: 2026-10-23
        ---
        body
        """
        var document = try FrontmatterDocument(text: original)
        document.remove("complete_instances")
        document.remove("status")
        document.remove("absent")
        let expected = """
        ---
        tags:
          - a
        # about status


        # trailing
        due: 2026-10-23
        ---
        body
        """
        expectSameBytes(document.text, expected)
        #expect(document.keys == ["tags", "due"])
    }

    @Test func replacingScalarWithListAndBack() throws {
        let original = "---\nstatus: open\ndue: 2026-10-23\nrecurrence_anchor: scheduled\n---\nbody"
        var document = try FrontmatterDocument(text: original)

        document.set("due", to: .list([.string("2026-10-23"), .string("2026-10-24")]))
        expectSameBytes(document.text, "---\nstatus: open\ndue:\n  - 2026-10-23\n  - 2026-10-24\nrecurrence_anchor: scheduled\n---\nbody")

        document.set("due", to: .string("2026-10-23"))
        expectSameBytes(document.text, original)
    }

    @Test func listOfMapsRoundTripsInTaskNotesShape() throws {
        var document = try FrontmatterDocument(text: Notes.rich)
        let previous = try #require(try document.value(for: "previous_task"))
        document.set("previous_task", to: previous)
        expectSameBytes(document.text, Notes.rich)

        let relation = { (name: String) in
            YAMLValue.map([
                YAMLMapEntry(key: "uid", value: .string("[[\(name)]]")),
                YAMLMapEntry(key: "reltype", value: .string("FINISHTOSTART")),
            ])
        }
        document.set("previous_task", to: .list([relation("Купить батарейки"), relation("Позвонить папе")]))
        let expected = Notes.rich.replacingOccurrences(
            of: "    reltype: FINISHTOSTART\n",
            with: "    reltype: FINISHTOSTART\n  - uid: \"[[Позвонить папе]]\"\n    reltype: FINISHTOSTART\n"
        )
        expectSameBytes(document.text, expected)
    }

    @Test(arguments: Notes.validSamples)
    func unchangedDocumentRoundTrips(text: String) throws {
        expectSameBytes(try FrontmatterDocument(text: text).text, text)
    }

    // MARK: - Reading

    @Test func readsEveryValueOfTheSampleNote() throws {
        let document = try FrontmatterDocument(text: Notes.rich)
        #expect(document.keys == [
            "tags", "status", "priority", "due", "time_estimate", "previous_task", "previous_event", "need_energy",
            "pleasant", "recurrence", "recurrence_anchor", "complete_instances", "contexts", "custom_plugin", "notes",
            "date_created",
        ])
        #expect(try document.value(for: "tags") == .list([.scalar("🔫делишка", quoted: false), .scalar("#дом", quoted: true)]))
        #expect(try document.value(for: "status") == .scalar("this_week", quoted: false))
        #expect(try document.value(for: "priority")?.string == "high")
        #expect(try document.value(for: "due")?.string == "2026-10-23T16:00")
        #expect(try document.value(for: "time_estimate")?.int == 15)
        #expect(try document.value(for: "previous_task") == .list([.map([
            YAMLMapEntry(key: "uid", value: .scalar("[[Купить батарейки]]", quoted: true)),
            YAMLMapEntry(key: "reltype", value: .scalar("FINISHTOSTART", quoted: false)),
        ])]))
        #expect(try document.value(for: "previous_event") == .scalar("8A1F…:A2B3…|Call with dad|2026-10-23T19:00:00+02:00", quoted: true))
        #expect(try document.value(for: "need_energy")?.bool == true)
        #expect(try document.value(for: "pleasant")?.bool == false)
        #expect(try document.value(for: "recurrence")?.string == "DTSTART:20261001T090000Z;FREQ=DAILY")
        #expect(try document.value(for: "recurrence_anchor")?.string == "scheduled")
        #expect(try document.value(for: "complete_instances")?.list?.compactMap(\.string) == ["2026-10-20", "2026-10-21"])
        #expect(try document.value(for: "contexts") == .list([
            .scalar("home", quoted: false), .scalar("errands, city", quoted: true), .scalar("it's", quoted: true),
        ]))
        #expect(try document.value(for: "custom_plugin") == .map([
            YAMLMapEntry(key: "nested", value: .map([
                YAMLMapEntry(key: "depth", value: .scalar("2", quoted: false)),
                YAMLMapEntry(key: "note", value: .scalar(#"escaped "quote" and \ backslash"#, quoted: true)),
            ])),
            YAMLMapEntry(key: "flag", value: .scalar("yes", quoted: false)),
        ]))
        #expect(try document.value(for: "notes")?.string == "Первая строка\n  с отступом\n\nпосле пустой строки 😀\n")
        #expect(try document.value(for: "date_created")?.string == "2026-10-20T09:12:44.123+02:00")
        #expect(try document.value(for: "deadline") == nil)
        expectSameBytes(document.body, Notes.body)
    }

    @Test func rawValueIsTheKeysExactLines() throws {
        let document = try FrontmatterDocument(text: Notes.rich.replacingOccurrences(of: "\n", with: "\r\n"))
        #expect(document.rawValue(for: "tags") == "tags:\r\n  - 🔫делишка\r\n  - \"#дом\"\r\n")
        #expect(document.rawValue(for: "priority") == "priority: high # important\r\n")
        #expect(document.rawValue(for: "absent") == nil)
    }

    @Test func duplicateKeysReadAndReplaceTheFirst() throws {
        var document = try FrontmatterDocument(text: "---\nstatus: open\nstatus: done\n---\n")
        #expect(document.keys == ["status"])
        #expect(try document.value(for: "status")?.string == "open")
        document.set("status", to: .string("waiting"))
        expectSameBytes(document.text, "---\nstatus: waiting\nstatus: done\n---\n")
        document.remove("status")
        expectSameBytes(document.text, "---\n---\n")
    }

    @Test func delimiterVariants() throws {
        let dots = try FrontmatterDocument(text: "---  \nstatus: open\n...\t\n---\nbody\n")
        #expect(try dots.value(for: "status")?.string == "open")
        #expect(dots.body == "---\nbody\n")

        let noTrailingBreak = try FrontmatterDocument(text: "---\nstatus: open\n---")
        #expect(noTrailingBreak.body == "")
        #expect(try noTrailingBreak.value(for: "status")?.string == "open")

        let quotedKey = try FrontmatterDocument(text: "---\n\"my key\": 'value'\n---\n")
        #expect(quotedKey.keys == ["my key"])
        #expect(try quotedKey.value(for: "my key") == .scalar("value", quoted: true))
    }

    // MARK: - Broken notes

    @Test(arguments: [
        ("", FrontmatterError.noFrontmatter),
        ("Just a note\n", .noFrontmatter),
        ("\n---\nstatus: open\n---\n", .noFrontmatter),
        (" ---\nstatus: open\n---\n", .noFrontmatter),
        ("---", .unterminated),
        ("---\nstatus: open\n", .unterminated),
        ("---\nstatus: open\n-- \nbody\n", .unterminated),
        ("---\nstatus: open\njust words\n---\n", .malformedLine(line: 3, text: "just words")),
        ("---\ntags:\n\t- a\n---\n", .malformedLine(line: 3, text: "\t- a")),
        ("---\n  - a\nstatus: open\n---\n", .malformedLine(line: 2, text: "  - a")),
        ("---\nstatus: open\n- a\n---\n", .malformedLine(line: 3, text: "- a")),
        ("---\nurl:http://example.com\n---\n", .malformedLine(line: 2, text: "url:http://example.com")),
    ])
    func brokenStructureIsRejected(text: String, expected: FrontmatterError) {
        #expect(frontmatterError(of: { _ = try FrontmatterDocument(text: text) }) == expected)
    }

    @Test(arguments: [
        ("---\nstatus: open\nprevious_event: \"abc|def\n---\n", "previous_event", 3, "unterminated double-quoted string"),
        ("---\ntitle: 'it''s\n---\n", "title", 2, "unterminated single-quoted string"),
        ("---\ntags: [a, \"b\"\nstatus: open\n---\n", "tags", 2, "unterminated flow sequence"),
        ("---\ntags: [a,\n  b\n---\n", "tags", 2, "unterminated flow sequence"),
        ("---\nmeta: {a: [1, 2}\n---\n", "meta", 2, "unbalanced '}'"),
        ("---\ntitle: \"a\" b\n---\n", "title", 2, "unexpected text after the value"),
        ("---\ntags: [a]\n  - b\n---\n", "tags", 3, "unexpected text after the value"),
    ])
    func unbalancedValuesAreRejected(text: String, key: String, line: Int, reason: String) {
        #expect(frontmatterError(of: { _ = try FrontmatterDocument(text: text) }) == .malformedValue(key: key, line: line, reason: reason))
    }

    @Test func multiLineQuotedAndFlowValuesAreValid() throws {
        let document = try FrontmatterDocument(text: "---\ntags: [a,\n  'b, c']\ntitle: \"one\n  two\"\n---\n")
        #expect(try document.value(for: "tags") == .list([.scalar("a", quoted: false), .scalar("b, c", quoted: true)]))
        #expect(try document.value(for: "title") == .scalar("one two", quoted: true))
    }
}

func expectSameBytes(_ actual: String, _ expected: String, sourceLocation: SourceLocation = #_sourceLocation) {
    #expect(actual == expected, sourceLocation: sourceLocation)
    #expect(Array(actual.utf8) == Array(expected.utf8), "UTF-8 bytes differ", sourceLocation: sourceLocation)
}

func frontmatterError(of body: () throws -> Void) -> FrontmatterError? {
    do {
        try body()
        return nil
    } catch let error as FrontmatterError {
        return error
    } catch {
        return nil
    }
}
