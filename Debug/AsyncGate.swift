#if DEBUG
import Foundation

/// A gate that async work waits at until a test opens it: tests put overlapping work in a fixed order with it instead
/// of sleeping and hoping the other side got there first. Once open it stays open.
actor AsyncGate {
    private var isOpen: Bool
    private var waiting: [CheckedContinuation<Void, Never>] = []
    private var arrivals = 0
    private var arrivalWatchers: [(count: Int, continuation: CheckedContinuation<Void, Never>)] = []

    init(isOpen: Bool = false) {
        self.isOpen = isOpen
    }

    /// Waits until the gate is open.
    func pass() async {
        arrivals += 1
        let reached = arrivalWatchers.filter { $0.count <= arrivals }
        arrivalWatchers.removeAll { $0.count <= arrivals }
        reached.forEach { $0.continuation.resume() }
        guard !isOpen else { return }
        await withCheckedContinuation { waiting.append($0) }
    }

    func open() {
        isOpen = true
        waiting.forEach { $0.resume() }
        waiting = []
    }

    /// Returns once `count` callers in all have reached the gate.
    func arrived(_ count: Int = 1) async {
        guard arrivals < count else { return }
        await withCheckedContinuation { arrivalWatchers.append((count, $0)) }
    }
}
#endif
