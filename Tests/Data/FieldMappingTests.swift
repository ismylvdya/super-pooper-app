import Foundation
import Testing
@testable import SuperPooperApp

/// The one table between the keys of `field-mapping.json` and the domain's fields.
@Suite("Field mapping")
struct FieldMappingTests {
    @Test func everyKeyTheReaderReadsHoldsADomainFieldAndEveryFieldHasAKey() throws {
        let mapping = TestConfig.mapping
        let data = try JSONEncoder().encode(mapping.fields)
        let keys = try #require(try JSONSerialization.jsonObject(with: data) as? [String: String])
        for (name, key) in keys where name != "tags" {
            #expect(mapping.field(forKey: key) != nil, "no domain field for \(key)")
        }
        #expect(Set(mapping.keyedFields.map(\.field)) == Set(TaskField.allCases))
    }

    /// The Inbox is TaskNotes' status `inbox`, read and written as is.
    @Test func inboxReadsAndWritesAsInbox() {
        #expect(TestConfig.mapping.status(fromRaw: "inbox") == .inbox)
        #expect(TestConfig.mapping.raw(.inbox) == "inbox")
    }

    @Test func everyFieldHasAName() {
        // Unit tests run inside the app, whose bundle holds the texts.
        let bundle = Bundle.main
        for field in TaskField.allCases {
            let key = "field." + field.rawValue
            #expect(bundle.localizedString(forKey: key, value: "∅", table: nil) != "∅", "missing text for \(key)")
        }
    }

    /// Obsidian's own names come from the adapter's config: the note file extension a link may carry, the vault folder.
    @Test func obsidianNamesComeFromTheMapping() {
        let obsidian = TestConfig.mapping.obsidian
        #expect(WikiLink.noteName(from: "[Alias](Tasks/Name.md)", noteExtension: obsidian.noteExtension) == "Name")
        #expect(WikiLink.noteName(from: "Name.txt", noteExtension: "txt") == "Name")
        #expect(WikiLink.noteName(from: "Name.md", noteExtension: "txt") == "Name.md")
        #expect(obsidian.configFolder == ".obsidian")
        #expect(obsidian.openURL.scheme == "obsidian")
    }
}
