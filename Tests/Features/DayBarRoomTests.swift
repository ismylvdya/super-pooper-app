import CoreGraphics
import Testing
@testable import SuperPooperApp

/// The day's name and arrows get the room between the bar's button groups, so the arrows never reach under the buttons
/// beside them (an arrow's outer edge took no taps there).
struct DayBarRoomTests {
    @Test func theRoomIsBetweenTheGroupsLessAGapOnEachSide() throws {
        let leading = [CGRect(x: 16, y: 62, width: 35, height: 32), CGRect(x: 59, y: 62, width: 56, height: 33)]
        let trailing = [CGRect(x: 305, y: 63, width: 39, height: 30), CGRect(x: 352, y: 62, width: 34, height: 33)]
        let room = try #require(DayBarRoom.width(leading: leading, trailing: trailing, gap: 8, center: 210))
        #expect(abs(room - (305 - 115 - 16)) < 0.001)
    }

    @Test func nothingIsDecidedBeforeBothGroupsAreMeasured() {
        #expect(DayBarRoom.width(leading: [], trailing: [CGRect(x: 300, y: 0, width: 40, height: 30)], gap: 8, center: 200) == nil)
        #expect(DayBarRoom.width(leading: [CGRect(x: 0, y: 0, width: 300, height: 30)],
                                 trailing: [CGRect(x: 290, y: 0, width: 40, height: 30)], gap: 8, center: 200) == 0)
    }

    /// One button on the left and a wider group on the right: the room is cut to the narrower side, so the name stays in
    /// the screen's middle.
    @Test func theRoomStaysCentredOnTheScreen() throws {
        let room = try #require(DayBarRoom.width(leading: [CGRect(x: 16, y: 0, width: 44, height: 44)],
                                                 trailing: [CGRect(x: 305, y: 0, width: 80, height: 44)], gap: 8, center: 200))
        #expect(abs(room - ((305 - 200) * 2 - 16)) < 0.001)
    }
}
