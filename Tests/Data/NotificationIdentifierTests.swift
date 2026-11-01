import Testing
@testable import SuperPooperApp

struct NotificationIdentifierTests {
    @Test func aRestoredNotificationHasAnIdentifierOfItsOwn() {
        let slot = "sp|habit|Вода|09:00"
        let restored = NotificationIdentifier.restored(slot)
        #expect(restored != slot)
        #expect(NotificationIdentifier.isRestored(restored))
        #expect(NotificationIdentifier.restored(restored) == restored)
        #expect(NotificationIdentifier.shown(restored) == slot)
        #expect(NotificationIdentifier.shown(NotificationIdentifier.restored(NotificationIdentifier.late(slot)))
                == NotificationIdentifier.late(slot))
        #expect(!NotificationIdentifier.isRestored(slot))
    }
}
