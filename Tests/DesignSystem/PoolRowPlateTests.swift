import Testing
@testable import SuperPooperApp

/// A high-priority tint is the row's own rounded plate, also when the row stands on a routine's square piece.
struct PoolRowPlateTests {
    @Test func theTintIsTheRowsRoundedPlateOnEveryPlate() {
        #expect(PoolRowPlate.own.tintCorners == .row)
        #expect(PoolRowPlate.piece.tintCorners == .row)
    }
}
