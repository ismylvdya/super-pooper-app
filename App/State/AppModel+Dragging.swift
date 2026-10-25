import Foundation

/// Tasks dragged on Today: onto the timeline (a date and time), back to the pool (no time), within the pool (order).
extension AppModel {
    func schedule(_ name: String, at moment: Date) async {
        guard let task = task(named: name) else { return }
        await write(task, TaskScheduling.changes(scheduling: task, at: moment, calendar: calendar))
    }

    /// Back to the pool at the spot it was dropped on.
    func unschedule(_ name: String, poolOrder: [String]) async {
        guard let task = task(named: name) else { return }
        await write(task, TaskScheduling.changes(unscheduling: task, context: context()))
        setManualOrder(poolOrder)
    }
}
