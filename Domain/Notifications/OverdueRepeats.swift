import Foundation

/// A habit's block or a timed task of today left open past its time (`NotificationSettings.repeatsOverdue`): its
/// notification comes again every `minutes`, the next `count` of them planned ahead, each taking the place of the one
/// before in Notification Center (`NotificationIdentifier.again`). Only what is still open today is in `today`: a done,
/// skipped or moved item has no notification there to repeat.
enum OverdueRepeats {
    static func notifications(_ today: [PlannedNotification], minutes: Int, count: Int, context: DayContext) -> [PlannedNotification] {
        guard minutes > 0, count > 0 else { return [] }
        let step = TimeInterval(minutes * 60)
        return today.filter { ($0.kind == .habit || $0.kind == .task) && $0.day == context.today && $0.fireDate <= context.now }
            .flatMap { original -> [PlannedNotification] in
                let passed = Int(context.now.timeIntervalSince(original.fireDate) / step)
                return (passed + 1...passed + count).compactMap { round in
                    let moment = original.fireDate.addingTimeInterval(step * Double(round))
                    guard moment < context.dayEnd else { return nil }
                    return original.snoozed(until: moment).identified(as: "again|\(original.key)|\(original.day.isoString)|\(round)")
                }
            }
    }
}
