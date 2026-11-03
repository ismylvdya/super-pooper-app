import Testing
@testable import SuperPooperApp

/// One arming rule for a list pulled down and the first page of Tasks pulled sideways.
struct PullArmingTests {
    @Test func pullArmingArmsOnceAndRunsOnRelease() {
        var arming = PullArming()
        let early = arming.update(pull: 59, threshold: 60)
        let armed = arming.update(pull: 61, threshold: 60)
        let again = arming.update(pull: 70, threshold: 60)
        let runs = arming.release()
        let runsTwice = arming.release()
        #expect(!early && armed && !again)
        #expect(runs && !runsTwice)
    }

    @Test func underHalfTheThresholdItDisarms() {
        var arming = PullArming()
        _ = arming.update(pull: 61, threshold: 60)
        _ = arming.update(pull: 40, threshold: 60)
        #expect(arming.isArmed, "still armed above half")
        _ = arming.update(pull: 29, threshold: 60)
        let runs = arming.release()
        #expect(!runs)
    }

    /// The content moves almost with the finger at first and less and less further on, never past the dimension.
    @Test func aPullResistsMoreTheFurtherItGoes() {
        let near = PullArming.stretch(10, dimension: 400, resistance: 0.55)
        let far = PullArming.stretch(400, dimension: 400, resistance: 0.55)
        #expect(near > 5 && near < 10)
        #expect(far < 400 * 0.55)
        #expect(PullArming.stretch(10_000, dimension: 400, resistance: 0.55) < 400)
        #expect(PullArming.stretch(-20, dimension: 400, resistance: 0.55) == 0)
    }
}
