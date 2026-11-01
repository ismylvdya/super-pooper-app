import Foundation
import Testing
@testable import SuperPooperApp

/// The notification work in one line: a plan replaced by a newer one is skipped, a restore always runs.
@MainActor
struct NotificationQueueTests {
    @Test func aPlanReplacedBeforeItStartsIsSkipped() async {
        let queue = NotificationQueue()
        let gate = AsyncGate()
        var log: [String] = []
        await queue.restore { log.append("restore") }
        queue.schedulePlan { await gate.pass(); log.append("first") }
        await gate.arrived()
        queue.schedulePlan { log.append("second") }
        queue.schedulePlan { log.append("third") }
        await gate.open()
        await queue.waitUntilIdle()
        #expect(log == ["restore", "first", "third"])
    }

    /// A plan asked for after a restore waits for it and never cancels it.
    @Test func aRestoreIsNeverCancelledByALaterPlan() async {
        let queue = NotificationQueue()
        let gate = AsyncGate()
        var log: [String] = []
        queue.schedulePlan { await gate.pass(); log.append("plan") }
        await gate.arrived()
        let restoring = Task { await queue.restore { log.append(Task.isCancelled ? "cancelled restore" : "restore") } }
        while queue.enqueued < 2 { await Task.yield() }
        queue.schedulePlan { log.append("later plan") }
        await gate.open()
        await restoring.value
        await queue.waitUntilIdle()
        #expect(log == ["plan", "restore", "later plan"])
    }

    @Test func waitingForIdleIncludesWorkAddedMeanwhile() async {
        let queue = NotificationQueue()
        var log: [String] = []
        queue.schedulePlan { log.append("plan"); queue.schedulePlan { log.append("next plan") } }
        await queue.waitUntilIdle()
        #expect(log == ["plan", "next plan"])
    }
}
