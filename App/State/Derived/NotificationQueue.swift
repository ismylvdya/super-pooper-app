import Foundation

/// The notification work in one line: a plan or a restore starts only when the work before it is done. A newer plan
/// replaces the one still waiting or running (a running plan stops adding requests); a restore is never cancelled, so a
/// plan asked for after it finds the request it put back.
@MainActor
final class NotificationQueue {
    private var tail: Task<Void, Never>?
    private var plan: Task<Void, Never>?
    /// How many jobs were put in line so far.
    private(set) var enqueued = 0

    func schedulePlan(_ work: @escaping @MainActor () async -> Void) {
        plan?.cancel()
        let job = enqueue { previous in
            await previous?.value
            guard !Task.isCancelled else { return }
            await work()
        }
        plan = job
    }

    func restore(_ work: @escaping @MainActor () async -> Void) async {
        await enqueue { previous in
            await previous?.value
            await work()
        }.value
    }

    /// Returns when everything put in line so far, and whatever was put in line meanwhile, is done.
    func waitUntilIdle() async {
        while let job = tail {
            await job.value
            if tail == job { break }
        }
    }

    private func enqueue(_ body: @escaping @MainActor (Task<Void, Never>?) async -> Void) -> Task<Void, Never> {
        let previous = tail
        let job = Task { @MainActor in await body(previous) }
        tail = job
        enqueued += 1
        return job
    }
}
