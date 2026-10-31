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

    @Test func everyFieldHasAName() {
        // Unit tests run inside the app, whose bundle holds the texts.
        let bundle = Bundle.main
        for field in TaskField.allCases {
            let key = "field." + field.rawValue
            #expect(bundle.localizedString(forKey: key, value: "∅", table: nil) != "∅", "missing text for \(key)")
        }
    }
}
