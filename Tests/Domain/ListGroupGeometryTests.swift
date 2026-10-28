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
}
