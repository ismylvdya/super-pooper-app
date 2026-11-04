import AlarmKit
import CryptoKit
import Foundation
import SwiftUI

/// What an alarm of the app carries: nothing beyond its title.
nonisolated struct ItemAlarmMetadata: AlarmMetadata {}

/// Sets alarms with AlarmKit. An alarm's id comes from everything about it, so what is set and what is wanted are compared
/// by id alone.
struct SystemAlarmScheduler: AlarmScheduling {
    let stopTitle: @Sendable () -> String
    let stopIcon: String
    let tint: @Sendable () -> Color

    func requestAccess() async -> Bool {
        let manager = AlarmManager.shared
        switch manager.authorizationState {
        case .authorized: return true
        case .denied: return false
        case .notDetermined: return (try? await manager.requestAuthorization()) == .authorized
        @unknown default: return false
        }
    }

    func sync(_ alarms: [PlannedAlarm]) async {
        let manager = AlarmManager.shared
        guard manager.authorizationState == .authorized else { return }
        let wanted = Dictionary(alarms.map { (Self.uuid(of: $0.id), $0) }, uniquingKeysWith: { first, _ in first })
        let set = Set((try? manager.alarms.map(\.id)) ?? [])
        for id in set.subtracting(wanted.keys) { try? manager.cancel(id: id) }
        for (id, alarm) in wanted where !set.contains(id) {
            _ = try? await manager.schedule(id: id, configuration: configuration(of: alarm))
        }
    }

    private func configuration(of alarm: PlannedAlarm) -> AlarmManager.AlarmConfiguration<ItemAlarmMetadata> {
        let stop = AlarmButton(text: LocalizedStringResource(stringLiteral: stopTitle()), textColor: .white, systemImageName: stopIcon)
        let alert = AlarmPresentation.Alert(title: LocalizedStringResource(stringLiteral: alarm.title), stopButton: stop)
        let attributes = AlarmAttributes(presentation: AlarmPresentation(alert: alert), metadata: ItemAlarmMetadata(), tintColor: tint())
        return .alarm(schedule: .fixed(alarm.fireDate), attributes: attributes, sound: alarm.soundFile.map { .named($0) } ?? .default)
    }

    private static func uuid(of id: String) -> UUID {
        let digest = Array(Insecure.MD5.hash(data: Data(id.utf8)))
        return UUID(uuid: (digest[0], digest[1], digest[2], digest[3], digest[4], digest[5], digest[6], digest[7],
                           digest[8], digest[9], digest[10], digest[11], digest[12], digest[13], digest[14], digest[15]))
    }
}
