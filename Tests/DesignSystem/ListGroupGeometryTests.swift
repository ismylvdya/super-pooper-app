import CoreGraphics
import Testing
@testable import SuperPooperApp

/// A group's backing spans its rows from the first one's top to the last one's bottom; a side whose end row is out
/// of sight stays open past the screen. While a drag moves the rows out of their order the backing stays put, in the
/// list's content.
@MainActor
struct ListGroupGeometryTests {
    private let screen: ClosedRange<CGFloat> = 0...800

    private func row(_ y: CGFloat, _ index: Int, of count: Int, height: CGFloat = 44) -> ListGroupFrames.Row {
        .init(frame: CGRect(x: 16, y: y, width: 300, height: height), index: index, count: count)
    }

    private func frames(_ rows: [String: ListGroupFrames.Row], group: String = "g") -> ListGroupFrames {
        let frames = ListGroupFrames()
        frames.setViewport(screen)
        rows.forEach { frames.set($1, group: group, id: $0) }
        return frames
    }

    @Test func theBackingSpansTheGroup() {
        let frames = frames(["b": row(144, 1, of: 3), "a": row(100, 0, of: 3), "c": row(188, 2, of: 3)])
        #expect(frames.plate(of: "g", overhang: 52) == CGRect(x: 16, y: 100, width: 300, height: 132))
    }

    @Test func aGroupScrolledPartlyAwayStaysOpenOnThatSide() {
        var top = row(-34, 0, of: 3)
        top.isVisible = false
        let frames = frames(["a": top, "b": row(10, 1, of: 3), "c": row(54, 2, of: 3)])
        let plate = frames.plate(of: "g", overhang: 52)
        #expect(plate?.minY == -52 && plate?.maxY == 98)
    }

    /// Soon on iOS 18.6 (frames logged while a UI test held the drag): the first row lifted and held over the third
    /// slot. Its hidden cell takes that slot and the two rows below it move up, so the rows still touch — the backing
    /// used to start at the dragged row's new slot. It stays where the rows stood, as tall as all of them.
    @Test func dragTheFirstRowDownTheBackingStays() {
        let frames = frames(["water": row(176, 0, of: 4, height: 62.33), "stretch": row(238.33, 1, of: 4, height: 62.5),
                             "shower": row(300.83, 2, of: 4, height: 63), "breakfast": row(363.83, 3, of: 4, height: 62.5)])
        let resting = frames.plate(of: "g", overhang: 52)
        #expect(resting?.minY == 176)
        frames.set(row(176, 1, of: 4, height: 62.5), group: "g", id: "stretch")
        frames.set(row(238.5, 2, of: 4, height: 63), group: "g", id: "shower")
        frames.set(row(301.33, 0, of: 4, height: 62.33), group: "g", id: "water")
        #expect(frames.plate(of: "g", overhang: 52) == resting)
    }

    /// The last row dragged above the others: the rows move down, the backing does not.
    @Test func dragTheLastRowUpTheBackingStays() {
        let frames = frames(["a": row(100, 0, of: 3), "b": row(144, 1, of: 3), "c": row(188, 2, of: 3)])
        frames.set(row(100, 2, of: 3), group: "g", id: "c")
        frames.set(row(144, 0, of: 3), group: "g", id: "a")
        frames.set(row(188, 1, of: 3), group: "g", id: "b")
        #expect(frames.plate(of: "g", overhang: 52) == CGRect(x: 16, y: 100, width: 300, height: 132))
    }

    /// A row dragged into another group (Soon: Morning to Day): the rows of both groups move aside; both backings stay.
    @Test func aRowDraggedIntoAnotherGroupMovesNeitherBacking() {
        let frames = frames(["a": row(100, 0, of: 2), "b": row(144, 1, of: 2)], group: "morning")
        frames.set(row(240, 0, of: 2), group: "day", id: "c")
        frames.set(row(284, 1, of: 2), group: "day", id: "d")
        frames.set(row(100, 1, of: 2), group: "morning", id: "b")
        frames.set(row(196, 0, of: 2), group: "morning", id: "a")
        frames.set(row(328, 1, of: 2), group: "day", id: "d")
        #expect(frames.plate(of: "morning", overhang: 52) == CGRect(x: 16, y: 100, width: 300, height: 88))
        #expect(frames.plate(of: "day", overhang: 52) == CGRect(x: 16, y: 240, width: 300, height: 88))
    }

    /// A row dragged from Morning past Day into Evening: Day's rows all move up together, in their order — its backing
    /// stays too, as no group's backing moves while a row is out of its place.
    @Test func aGroupWhoseRowsAllMoveAsideKeepsItsBacking() {
        let frames = frames(["a": row(100, 0, of: 2), "b": row(144, 1, of: 2)], group: "morning")
        frames.set(row(240, 0, of: 2), group: "day", id: "c")
        frames.set(row(284, 1, of: 2), group: "day", id: "d")
        frames.set(row(380, 1, of: 2), group: "morning", id: "b")
        frames.set(row(196, 0, of: 2), group: "day", id: "c")
        frames.set(row(240, 1, of: 2), group: "day", id: "d")
        #expect(frames.plate(of: "day", overhang: 52) == CGRect(x: 16, y: 240, width: 300, height: 88))
        #expect(frames.plate(of: "morning", overhang: 52) == CGRect(x: 16, y: 100, width: 300, height: 88))
    }

    /// The list scrolls while a row is dragged (to a place out of sight): the backing goes with the content.
    @Test func aHeldBackingScrollsWithTheList() {
        let frames = frames(["a": row(100, 0, of: 3), "b": row(144, 1, of: 3), "c": row(188, 2, of: 3)])
        frames.set(row(100, 1, of: 3), group: "g", id: "b")
        frames.set(row(144, 0, of: 3), group: "g", id: "a")
        frames.setScrollOffset(30)
        frames.set(row(70, 1, of: 3), group: "g", id: "b")
        frames.set(row(114, 0, of: 3), group: "g", id: "a")
        frames.set(row(158, 2, of: 3), group: "g", id: "c")
        #expect(frames.plate(of: "g", overhang: 52) == CGRect(x: 16, y: 70, width: 300, height: 132))
    }

    /// A list that takes the lifted row's cell away while it is dragged: the row below does not take the first row's
    /// place in the backing.
    @Test func aFirstRowTakenOutOfTheListKeepsTheBacking() {
        let frames = frames(["a": row(100, 0, of: 3), "b": row(144, 1, of: 3), "c": row(188, 2, of: 3)])
        frames.setVisible(false, group: "g", id: "a")
        frames.set(row(100, 1, of: 3), group: "g", id: "b")
        frames.set(row(144, 2, of: 3), group: "g", id: "c")
        #expect(frames.plate(of: "g", overhang: 52) == CGRect(x: 16, y: 100, width: 300, height: 132))
    }

    /// The drop: the rows take their new places in the group's order, and the backing follows them again.
    @Test func afterTheDropTheBackingFollowsTheRows() {
        let frames = frames(["a": row(100, 0, of: 2), "b": row(144, 1, of: 2)])
        frames.set(row(100, 1, of: 2), group: "g", id: "b")
        frames.set(row(144, 0, of: 2), group: "g", id: "a")
        frames.setPlace(index: 0, count: 2, group: "g", id: "b")
        frames.setPlace(index: 1, count: 2, group: "g", id: "a")
        frames.setScrollOffset(10)
        frames.set(row(90, 0, of: 2), group: "g", id: "b")
        frames.set(row(134, 1, of: 2), group: "g", id: "a")
        #expect(frames.plate(of: "g", overhang: 52) == CGRect(x: 16, y: 90, width: 300, height: 88))
    }

    /// The last row leaves the group (it moved to another one) without moving on screen: the group learns its new last
    /// row, so the backing ends there and does not reach under the next header.
    @Test func aNewLastRowIsLearnedWithoutAMove() {
        let frames = frames(["a": row(100, 0, of: 3), "b": row(144, 1, of: 3), "c": row(188, 2, of: 3)], group: "morning")
        frames.setPlace(index: 0, count: 2, group: "morning", id: "a")
        frames.setPlace(index: 1, count: 2, group: "morning", id: "b")
        frames.move("c", from: "morning", to: "day", index: 0, count: 1)
        #expect(frames.plate(of: "morning", overhang: 52) == CGRect(x: 16, y: 100, width: 300, height: 88))
        #expect(frames.rows["day"]?["c"]?.isFirst == true)
    }

    /// A note gone from the group leaves its row behind (out of sight, with the old count): it is not a row of the group.
    @Test func aRowOfAGoneNoteDoesNotCount() {
        let frames = frames(["a": row(100, 0, of: 3), "b": row(144, 1, of: 3), "c": row(188, 2, of: 3)])
        frames.setVisible(false, group: "g", id: "b")
        frames.set(row(144, 1, of: 2), group: "g", id: "c")
        frames.setPlace(index: 0, count: 2, group: "g", id: "a")
        #expect(frames.plate(of: "g", overhang: 52) == CGRect(x: 16, y: 100, width: 300, height: 88))
    }
}
