import Foundation

/// A time of an item rings as an alarm (AlarmKit), through silent mode and Focus, beside its notification. `time`: which of
/// a habit's times; a task has one time, whatever it is now, so the alarm follows it (nil). `sound`: a sound's id from
/// `rules.json` → `alarms`; nil = the one set in the settings.
struct TimeAlarm: Hashable, Codable, Sendable {
    var time: LocalTime?
    var sound: String?
}

extension TaskItem {
    /// The alarm of the block whose written time is `slot`.
    func alarm(at slot: LocalTime?) -> TimeAlarm? {
        isHabit ? alarms.first { $0.time == slot } : alarms.first
    }
}

extension [TimeAlarm] {
    /// The alarms after a habit's times changed from `old` to `new`: one time edited takes its alarm along; a removed
    /// time's alarm goes.
    func following(times old: [LocalTime], to new: [LocalTime]) -> [TimeAlarm] {
        guard old.count == new.count else { return filter { $0.time.map(new.contains) ?? false } }
        return compactMap { alarm in
            guard let index = old.firstIndex(where: { $0 == alarm.time }) else { return nil }
            return TimeAlarm(time: new[index], sound: alarm.sound)
        }
    }
}
