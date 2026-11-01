import Testing
import UIKit
@testable import SuperPooperApp

/// What a hex field of a color control stores (.24481: the habit color and the settings colors share one control).
struct ColorHexTests {
    @Test func typedHexIsStoredInCapitalsWithItsHash() {
        #expect("34c759".storableHexColor == "#34C759")
        #expect("#ff3b30".storableHexColor == "#FF3B30")
        #expect(" #00ff00 ".storableHexColor == "#00FF00")
        #expect("#11223344".storableHexColor == "#11223344")
    }

    @Test func textThatIsNoColorIsNotStored() {
        #expect("".storableHexColor == nil)
        #expect("#12345".storableHexColor == nil)
        #expect("green".storableHexColor == nil)
    }

    @Test func aPickedColorStoresAsItsHex() {
        #expect(UIColor(red: 1, green: 0, blue: 0, alpha: 1).hexString.storableHexColor == "#FF0000")
    }
}
