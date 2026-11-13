import Foundation
import Testing
@testable import SuperPooperApp

/// Return on a list line starts the next one with the same marker; on an empty item it ends the list.
@Suite("List continuation")
struct ListContinuationTests {
    private let markers = ["- ", "• "]

    @Test func aBulletGoesOnToTheNextLine() {
        #expect(ListContinuation.edit(from: "- milk", to: "- milk\n", markers: markers) == .init(text: "- milk\n- ", cursor: 9))
        #expect(ListContinuation.edit(from: "• one", to: "• one\n", markers: markers) == .init(text: "• one\n• ", cursor: 8))
    }

    @Test func inTheMiddleOfTheTextToo() {
        let edit = ListContinuation.edit(from: "Buy:\n- milk\nend", to: "Buy:\n- milk\n\nend", markers: markers)
        #expect(edit == .init(text: "Buy:\n- milk\n- \nend", cursor: 14))
    }

    @Test func anEmptyItemEndsTheList() {
        #expect(ListContinuation.edit(from: "- milk\n- ", to: "- milk\n- \n", markers: markers) == .init(text: "- milk\n", cursor: 7))
    }

    @Test func plainLinesAndPastesAreLeftAsTheyAre() {
        #expect(ListContinuation.edit(from: "milk", to: "milk\n", markers: markers) == nil)
        #expect(ListContinuation.edit(from: "- milk", to: "- milk\nbread", markers: markers) == nil)
        #expect(ListContinuation.edit(from: "- milk", to: "- milks", markers: markers) == nil)
    }
}
