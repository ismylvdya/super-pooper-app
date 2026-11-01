import CoreGraphics
import Testing
@testable import SuperPooperApp

/// A group's backing spans its rows from the first one's top to the last one's bottom; a side whose end row is out
/// of sight stays open past the screen.
@MainActor
struct ListGroupGeometryTests {
    private func row(_ y: CGFloat, first: Bool = false, last: Bool = false) -> ListGroupFrames.Row {
        .init(frame: CGRect(x: 16, y: y, width: 300, height: 44), isFirst: first, isLast: last)
    }

    @Test func theBackingSpansTheGroup() {
        let plate = ListGroupGeometry.plate(of: [row(144), row(100, first: true), row(188, last: true)], visible: 0...800, overhang: 52)
        #expect(plate == CGRect(x: 16, y: 100, width: 300, height: 132))
    }

    @Test func aGroupScrolledPartlyAwayStaysOpenOnThatSide() {
        let plate = ListGroupGeometry.plate(of: [row(10), row(54, last: true)], visible: 0...800, overhang: 52)
        #expect(plate?.minY == -52 && plate?.maxY == 98)
    }

    /// The first row lifted and dragged down moves with the finger; the backing keeps the group's top where the rows
    /// stood, and its height.
    @Test func aLiftedFirstRowLeavesTheTopInItsSlot() throws {
        let frames = ListGroupFrames()
        frames.set(row(100, first: true), group: "g", id: "a")
        frames.set(row(144), group: "g", id: "b")
        frames.set(row(188, last: true), group: "g", id: "c")
        frames.set(row(170, first: true), group: "g", id: "a")
        let rows = Array(try #require(frames.rows["g"]).values)
        let plate = ListGroupGeometry.plate(of: rows, visible: 0...800, overhang: 52, restingTop: frames.restingTops["g"])
        #expect(plate == CGRect(x: 16, y: 100, width: 300, height: 132))
    }

    /// The last row leaves the group (it moved to another one) without moving on screen: the group learns its new last
    /// row, so the backing ends there and does not reach under the next header.
    @Test func aNewLastRowIsLearnedWithoutAMove() throws {
        let frames = ListGroupFrames()
        frames.set(row(100, first: true), group: "morning", id: "a")
        frames.set(row(144), group: "morning", id: "b")
        frames.set(row(188, last: true), group: "morning", id: "c")
        frames.setEnds(isFirst: false, isLast: true, group: "morning", id: "b")
        frames.move("c", from: "morning", to: "day", isFirst: true, isLast: true)
        let morning = Array(try #require(frames.rows["morning"]).values)
        #expect(ListGroupGeometry.plate(of: morning, visible: 0...800, overhang: 52) == CGRect(x: 16, y: 100, width: 300, height: 88))
        #expect(frames.rows["day"]?["c"]?.isFirst == true)
    }
}
