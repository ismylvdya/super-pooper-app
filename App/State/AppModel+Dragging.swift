import Foundation

/// Tasks dragged on Today: onto the timeline (a date and time), back to the pool (no time), within the pool (order).
extension AppModel {
    /// The moment is read on the phone's clock and written in the note's own zone.
    func schedule(_ name: String, at moment: Date) async {
        guard let task = task(named: name) else { return }
        await writeLocal(task, TaskScheduling.changes(scheduling: task, at: moment, calendar: calendar))
    }

    /// Back to the pool at the spot it was dropped on, on the logical day it was shown on.
    func unschedule(_ name: String, poolOrder: [String]) async {
        guard let task = task(named: name), let local = localTask(named: name) else { return }
        await writeLocal(task, TaskScheduling.changes(unscheduling: local, context: context()))
        setManualOrder(poolOrder)
    }
}
