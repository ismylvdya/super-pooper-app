import Testing
@testable import SuperPooperApp

/// Reading values with `YAMLSubsetParser` and writing them with `YAMLSerializer`.
struct FrontmatterValueTests {
    private func value(_ frontmatter: String, _ key: String) throws -> YAMLValue? {
        try FrontmatterDocument(text: "---\n" + frontmatter + "\n---\n").value(for: key)
    }

    private func plain(_ text: String) -> YAMLValue { .scalar(text, quoted: false) }
    private func quoted(_ text: String) -> YAMLValue { .scalar(text, quoted: true) }

    // MARK: - Block collections

    @Test func columnZeroSequences() throws {
        #expect(try value("tags:\n- a\n# comment\n- b\nstatus: open", "tags") == .list([plain("a"), plain("b")]))
        let relations = "previous_task:\n- uid: \"[[X]]\"\n  reltype: FINISHTOSTART\n- \"[[Y]]\"\n- Z"
        #expect(try value(relations, "previous_task") == .list([
            .map([YAMLMapEntry(key: "uid", value: quoted("[[X]]")), YAMLMapEntry(key: "reltype", value: plain("FINISHTOSTART"))]),
            quoted("[[Y]]"),
            plain("Z"),
        ]))
    }

    @Test func indentedAndNestedCollections() throws {
        #expect(try value("tags:\n    - a\n\n    - b", "tags") == .list([plain("a"), plain("b")]))
        #expect(try value("grid:\n  - - a\n    - b\n  -\n    - c", "grid") == .list([
            .list([plain("a"), plain("b")]),
            .list([plain("c")]),
        ]))
        let nested = "custom:\n  nested:\n    depth: 2\n    list:\n    - x\n  empty:\n  flag: yes # comment"
        #expect(try value(nested, "custom") == .map([
            YAMLMapEntry(key: "nested", value: .map([
                YAMLMapEntry(key: "depth", value: plain("2")),
                YAMLMapEntry(key: "list", value: .list([plain("x")])),
            ])),
            YAMLMapEntry(key: "empty", value: .null),
            YAMLMapEntry(key: "flag", value: plain("yes")),
        ]))
    }

    // MARK: - Flow collections

    @Test func flowCollections() throws {
        #expect(try value(#"contexts: [home, "errands, city", 'it''s', [[Купить батарейки]], {k: v}]"#, "contexts") == .list([
            plain("home"),
            quoted("errands, city"),
            quoted("it's"),
            .list([.list([plain("Купить батарейки")])]),
            .map([YAMLMapEntry(key: "k", value: plain("v"))]),
        ]))
        #expect(try value("tags: []", "tags") == .list([]))
        #expect(try value("meta: {}", "meta") == .map([]))
        #expect(try value("tags: [a,\n  b, # comment\n  c, ]", "tags") == .list([plain("a"), plain("b"), plain("c")]))
        #expect(try value(#"rel: {uid: "[[X]]", reltype: FINISHTOSTART, empty: , "quoted key": 1, url: http://x.y}"#, "rel") == .map([
            YAMLMapEntry(key: "uid", value: quoted("[[X]]")),
            YAMLMapEntry(key: "reltype", value: plain("FINISHTOSTART")),
            YAMLMapEntry(key: "empty", value: .null),
            YAMLMapEntry(key: "quoted key", value: plain("1")),
            YAMLMapEntry(key: "url", value: plain("http://x.y")),
        ]))
        #expect(try value("pairs: [a: 1, b]", "pairs") == .list([.map([YAMLMapEntry(key: "a", value: plain("1"))]), plain("b")]))
        #expect(try value("tags:\n  [a, b]", "tags") == .list([plain("a"), plain("b")]))
    }

    // MARK: - Scalars

    @Test func parsesDoubleQuotedEscapes() throws {
        let text = #"title: "Tab\there \"q\" back\\slash é \U0001F600 \x41 \/ 😀 line\nbreak""#
        #expect(try value(text, "title") == quoted("Tab\there \"q\" back\\slash é 😀 A / 😀 line\nbreak"))
    }

    @Test func singleQuotedAndMultiLineStrings() throws {
        #expect(try value(#"title: 'it''s "fine" \n'"#, "title") == quoted(#"it's "fine" \n"#))
        #expect(try value("title: \"first\n  second\n\n  third \\\n  joined\"", "title") == quoted("first second\nthird joined"))
        #expect(try value("title: plain first\n  plain second\n\n  third", "title") == plain("plain first plain second\nthird"))
    }

    @Test func plainScalarsAndNulls() throws {
        let note = "a: value # comment\nb:\nc: ~\nd: null\ne: \"null\"\nf: a#b\ng: 8A1F:A2B3|x|2026-10-23T19:00:00+02:00\nh: # only comment"
        #expect(try value(note, "a") == plain("value"))
        #expect(try value(note, "b") == .null)
        #expect(try value(note, "c") == .null)
        #expect(try value(note, "d") == .null)
        #expect(try value(note, "e") == quoted("null"))
        #expect(try value(note, "f") == plain("a#b"))
        #expect(try value(note, "g") == plain("8A1F:A2B3|x|2026-10-23T19:00:00+02:00"))
        #expect(try value(note, "h") == .null)
    }

    @Test func blockScalars() throws {
        #expect(try value("notes: |\n  line 1\n    indented\n\n  line 3\nnext: x", "notes") == quoted("line 1\n  indented\n\nline 3\n"))
        #expect(try value("notes: >-\n  folded\n  text\n\n  paragraph", "notes") == quoted("folded text\nparagraph"))
        #expect(try value("notes: |-\n  a\n  b", "notes") == quoted("a\nb"))
        #expect(try value("notes: |2 # comment\n    two extra\n  base", "notes") == quoted("  two extra\nbase\n"))
        #expect(try value("list:\n  - |+\n    kept\n\n  - x", "list") == .list([quoted("kept\n\n"), plain("x")]))
    }

    // MARK: - Malformed values

    @Test(arguments: [
        ("custom:\n    a: 1\n  b: 2", "custom", 4, "bad indentation"),
        ("tags:\n  - a\n - b", "tags", 4, "bad indentation"),
        ("tags:\n  \t- a", "tags", 3, "tab indentation"),
        (#"title: "bad \q escape""#, "title", 2, "invalid escape sequence \\q"),
        ("title: a: b", "title", 2, "':' followed by a space needs quotes"),
        ("custom:\n  list: [a, b\nstatus: open", "custom", 3, "unterminated flow sequence"),
        ("previous_task:\n  - uid: \"[[X]]\n    reltype: FINISHTOSTART", "previous_task", 3, "unterminated double-quoted string"),
        ("custom:\n  a: 1\n  - b", "custom", 4, "expected 'key: value'"),
        ("notes: |x\n  text", "notes", 2, "invalid block scalar header"),
        ("tags: [a, , b]", "tags", 2, "missing value"),
    ])
    func malformedValuesThrow(frontmatter: String, key: String, line: Int, reason: String) {
        let failure = frontmatterError { _ = try value(frontmatter, key) }
        #expect(failure == .malformedValue(key: key, line: line, reason: reason))
    }

    @Test func malformedUnknownKeyDoesNotBreakTheNote() throws {
        let document = try FrontmatterDocument(text: "---\ncustom:\n    a: 1\n  b: 2\nstatus: open\n---\n")
        #expect(try document.value(for: "status") == plain("open"))
        #expect(frontmatterError { _ = try document.value(for: "custom") } != nil)
    }

    // MARK: - Accessors and factories

    @Test func accessors() {
        #expect(plain("TRUE").bool == true)
        #expect(plain("False").bool == false)
        #expect(quoted("true").bool == nil)
        #expect(plain("yes").bool == nil)
        #expect(plain("15").int == 15)
        #expect(quoted("15").int == 15)
        #expect(plain("15 min").int == nil)
        #expect(plain("a").list == nil)
        #expect(YAMLValue.list([plain("a")]).list == [plain("a")])
        #expect(YAMLValue.null.string == nil)
        #expect(YAMLValue.map([YAMLMapEntry(key: "uid", value: plain("x"))]).value(for: "uid") == plain("x"))
    }

    @Test func factories() {
        #expect(YAMLValue.string("done") == plain("done"))
        #expect(YAMLValue.string("[[X]]") == plain("[[X]]"))
        #expect(YAMLValue.string("2026-10-23") == plain("2026-10-23"))
        #expect(YAMLValue.string("true") == quoted("true"))
        #expect(YAMLValue.string("15") == quoted("15"))
        #expect(YAMLValue.string("~") == quoted("~"))
        #expect(YAMLValue.bool(true) == plain("true"))
        #expect(YAMLValue.int(-5) == plain("-5"))
    }

    // MARK: - Serializer

    @Test func serializesInObsidianStyle() {
        #expect(YAMLSerializer.lines(key: "status", value: .string("done")) == ["status: done"])
        #expect(YAMLSerializer.lines(key: "uid", value: .string("[[Купить батарейки]]")) == [#"uid: "[[Купить батарейки]]""#])
        #expect(YAMLSerializer.lines(key: "due", value: .null) == ["due:"])
        #expect(YAMLSerializer.lines(key: "tags", value: .list([])) == ["tags: []"])
        #expect(YAMLSerializer.lines(key: "meta", value: .map([])) == ["meta: {}"])
        #expect(YAMLSerializer.lines(key: "time_estimate", value: .int(15)) == ["time_estimate: 15"])
        #expect(YAMLSerializer.lines(key: "pleasant", value: .bool(false)) == ["pleasant: false"])
        #expect(YAMLSerializer.lines(key: "title", value: .string("true")) == [#"title: "true""#])
        #expect(YAMLSerializer.lines(key: "title", value: quoted("plain")) == [#"title: "plain""#])
        #expect(YAMLSerializer.lines(key: "my key:", value: plain("x")) == [#""my key:": x"#])

        let nested = YAMLValue.list([
            .map([
                YAMLMapEntry(key: "uid", value: .string("[[X]]")),
                YAMLMapEntry(key: "deps", value: .list([.string("a"), .null])),
                YAMLMapEntry(key: "reltype", value: .string("FINISHTOSTART")),
            ]),
            .list([.string("nested"), .list([])]),
            .map([YAMLMapEntry(key: "inner", value: .map([YAMLMapEntry(key: "k", value: .string("v"))]))]),
        ])
        #expect(YAMLSerializer.lines(key: "items", value: nested) == [
            "items:",
            #"  - uid: "[[X]]""#,
            "    deps:",
            "      - a",
            "      -",
            "    reltype: FINISHTOSTART",
            "  - - nested",
            "    - []",
            "  - inner:",
            "      k: v",
        ])
    }

    @Test(arguments: [
        "", " lead", "trail ", "- item", "-", "? q", ": c", ",", "[x", "]", "{", "}", "#tag", "&a", "*a", "!t", "|", ">",
        "'q", "\"q", "%", "@x", "`x", "a: b", "a #b", "ends:", "line\nbreak", "tab\there",
    ])
    func unsafeTextIsQuoted(text: String) {
        #expect(YAMLSerializer.needsQuotes(text))
    }

    @Test(arguments: [
        "this_week", "-5", "2026-10-23T16:00", "8A1F:A2B3|Call|2026-10-23T19:00:00+02:00", "a#b", "Купить батарейки 🔋",
        "?x", "http://x.y", "DTSTART:20261001T090000Z;FREQ=DAILY",
    ])
    func safeTextStaysPlain(text: String) {
        #expect(!YAMLSerializer.needsQuotes(text))
    }

    @Test func serializerEscapesControlCharacters() {
        #expect(YAMLSerializer.doubleQuoted("a\"b\\c\nd\te\r\0\u{1}\u{7F}\u{FEFF}é😀") == #""a\"b\\c\nd\te\r\0\x01\x7F\uFEFFé😀""#)
    }

    @Test(arguments: [
        YAMLValue.null,
        .scalar("plain", quoted: false),
        .scalar("[[Купить батарейки]]", quoted: true),
        .scalar("line\nbreak \"quoted\" \\ \u{1}", quoted: true),
        .string("true"),
        .int(-5),
        .list([]),
        .list([.scalar("a", quoted: false), .null, .list([.scalar("b", quoted: false)]), .map([])]),
        .map([
            YAMLMapEntry(key: "uid", value: .scalar("[[X]]", quoted: true)),
            YAMLMapEntry(key: "deps", value: .list([.map([YAMLMapEntry(key: "k", value: .scalar("v", quoted: false))])])),
        ]),
    ])
    func serializedValuesParseBack(value: YAMLValue) throws {
        let text = "---\n" + YAMLSerializer.lines(key: "key", value: value).joined(separator: "\n") + "\n---\n"
        #expect(try FrontmatterDocument(text: text).value(for: "key") == value)
    }
}
