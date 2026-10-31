import Foundation
@preconcurrency import UserNotifications
import Testing
@testable import SuperPooperApp

/// A notification swiped away is put back in line with the notification plans, so a sync never takes it away.
@MainActor
struct NotificationRestoreTests {
    private func swiped(on day: LocalDate) -> UNNotificationRequest {
        let content = UNMutableNotificationContent()
        content.userInfo = [NotificationPayload.dayKey: day.isoString]
        return UNNotificationRequest(identifier: "sp|habit|Вода|09:00", content: content, trigger: nil)
    }

    /// The reported bug: a sync running in the second before the restored notification showed removed it. The restore
    /// waits for the plan being scheduled, and the plan made after it waits for the restore.
    @Test func aRestoreRunsInLineWithThePlans() async throws {
        let slowCenter = AsyncGate()
        let recorder = RecordingNotifications(firstSync: slowCenter)
        let model = try #require(PreviewModel.make(notifications: recorder)).model
        await model.publishDerivedState()
        let planning = model.notificationTask
        let restoring = Task { await model.restoreNotification(swiped(on: model.context().today)) }
        while model.notificationTask == planning { await Task.yield() }
        await model.publishDerivedState()
        await slowCenter.open()
        await model.waitForNotifications()
        await restoring.value
        #expect(await recorder.log == ["sync", "restore sp|habit|Вода|09:00", "sync"])
    }

    @Test func aNotificationOfADayThatIsOverIsNotPutBack() async throws {
        let recorder = RecordingNotifications()
        let model = try #require(PreviewModel.make(notifications: recorder)).model
        await model.restoreNotification(swiped(on: model.context().today.adding(days: -1)))
        #expect(await recorder.log.isEmpty)
    }
}
