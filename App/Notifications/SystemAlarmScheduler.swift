import AlarmKit
import CryptoKit
import Foundation
import SwiftUI

/// What an alarm of the app carries: nothing beyond its title.
nonisolated struct ItemAlarmMetadata: AlarmMetadata {}

/// Sets alarms with AlarmKit. An alarm's id comes from everything about it, so what is set and what is wanted are compared
/// by id alone.
struct SystemAlarmScheduler: AlarmScheduling {
    /// The stop slider's word where iOS still lets an app name it (26.0; from 26.1 it is the system's own).
    let stopTitle: @Sendable () -> String
    let snoozeTitle: @Sendable () -> String
    let snoozeIcon: String
    let stopIcon: String
    /// The fill of the alarm's button, and its words on it: the alarm's screen is always dark.
    let tint: @Sendable () -> Color
    let buttonText: @Sendable () -> Color
    /// Changes with how an alarm looks: alarms set with another look are set anew.
    let styleKey: @Sendable () -> String

    func requestAccess() async -> Bool {
        let manager = AlarmManager.shared
        switch manager.authorizationState {
        case .authorized: return true
        case .denied: return false
        case .notDetermined: return (try? await manager.requestAuthorization()) == .authorized
        @unknown default: return false
        }
    }

    var isAuthorized: Bool { AlarmManager.shared.authorizationState == .authorized }

    func sync(_ alarms: [PlannedAlarm]) async {
        let manager = AlarmManager.shared
        guard manager.authorizationState == .authorized else { return }
        let wanted = Dictionary(alarms.map { (Self.uuid(of: $0.id + styleKey()), $0) }, uniquingKeysWith: { first, _ in first })
        let current = (try? manager.alarms) ?? []
        let set = Set(current.map(\.id))
        // One ringing now has left the plan with its moment: it rings on until it is stopped.
        for alarm in current where wanted[alarm.id] == nil && alarm.state != .alerting { try? manager.cancel(id: alarm.id) }
        for (id, alarm) in wanted where !set.contains(id) {
            _ = try? await manager.schedule(id: id, configuration: configuration(of: alarm))
        }
    }

    private func configuration(of alarm: PlannedAlarm) -> AlarmManager.AlarmConfiguration<ItemAlarmMetadata> {
        let attributes = AlarmAttributes(presentation: AlarmPresentation(alert: alert(of: alarm)), metadata: ItemAlarmMetadata(), tintColor: tint())
        return .alarm(schedule: .fixed(alarm.fireDate), attributes: attributes,
                      stopIntent: AlarmDoneIntent(taskName: alarm.taskName ?? "", day: alarm.day.isoString),
                      secondaryIntent: AlarmSnoozeIntent(key: alarm.key, day: alarm.day.isoString),
                      sound: alarm.soundFile.map { .named($0) } ?? .default)
    }

    /// The task's name as its title; the slider does Done (`AlarmDoneIntent`), the button Snooze (`AlarmSnoozeIntent`).
    private func alert(of alarm: PlannedAlarm) -> AlarmPresentation.Alert {
        let title = LocalizedStringResource(stringLiteral: alarm.title)
        let snooze = AlarmButton(text: LocalizedStringResource(stringLiteral: snoozeTitle()), textColor: buttonText(), systemImageName: snoozeIcon)
        if #available(iOS 26.1, *) {
            return AlarmPresentation.Alert(title: title, secondaryButton: snooze, secondaryButtonBehavior: .custom)
        }
        let stop = AlarmButton(text: LocalizedStringResource(stringLiteral: stopTitle()), textColor: buttonText(), systemImageName: stopIcon)
        return AlarmPresentation.Alert(title: title, stopButton: stop, secondaryButton: snooze, secondaryButtonBehavior: .custom)
    }

    private static func uuid(of id: String) -> UUID {
        let digest = Array(Insecure.MD5.hash(data: Data(id.utf8)))
        return UUID(uuid: (digest[0], digest[1], digest[2], digest[3], digest[4], digest[5], digest[6], digest[7],
                           digest[8], digest[9], digest[10], digest[11], digest[12], digest[13], digest[14], digest[15]))
    }
}
