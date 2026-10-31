import Foundation
import Testing
@testable import SuperPooperApp

/// The one bridge between frontmatter values and JSON (item settings, the older settings note).
@Suite("YAML and JSON")
struct YAMLJSONTests {
    @Test func unquotedScalarsAreTypedAndQuotedOnesStayText() {
        #expect(YAMLJSON.json(.scalar("true", quoted: false)) as? Bool == true)
        #expect(YAMLJSON.json(.scalar("5", quoted: false)) as? Int == 5)
        #expect(YAMLJSON.json(.scalar("0.5", quoted: false)) as? Double == 0.5)
        #expect(YAMLJSON.json(.scalar("5", quoted: true)) as? String == "5")
        #expect(YAMLJSON.json(.scalar("nan", quoted: false)) as? String == "nan")
        #expect(YAMLJSON.json(.null) is NSNull)
    }

    @Test func jsonComesBackAsTheValuesItSettingsWrite() {
        #expect(YAMLJSON.yaml(true as NSNumber) == .bool(true))
        #expect(YAMLJSON.yaml(5 as NSNumber) == .scalar("5", quoted: false))
        #expect(YAMLJSON.yaml("#FF9500") == .scalar("#FF9500", quoted: true))
        #expect(YAMLJSON.yaml(["09:00", "21:00"]) == .list([.scalar("09:00", quoted: true), .scalar("21:00", quoted: true)]))
        #expect(YAMLJSON.yaml(NSNull()) == nil)
    }
}
