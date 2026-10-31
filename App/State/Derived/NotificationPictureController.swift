import Foundation

/// The picture at the right of habit notifications: the user's own (this device) or the habit symbol, and whether it
/// takes the habit's color. The notifications planned from a change on carry it.
@MainActor
final class NotificationPictureController {
    private let images: NotificationImageStore
    private let settings: SettingsController
    private let derived: DerivedStatePublisher
    private let appEvents: AppEventSink

    init(images: NotificationImageStore, settings: SettingsController, derived: DerivedStatePublisher, appEvents: AppEventSink) {
        self.images = images
        self.settings = settings
        self.derived = derived
        self.appEvents = appEvents
    }

    /// The user's own picture, or nil for the habit symbol.
    var imageData: Data? { images.data() }

    /// Sets (or with nil removes) the picture.
    func setImage(_ data: Data?) async {
        if let data {
            do {
                try images.save(data)
            } catch {
                appEvents.send(.notificationImageFailed)
                return
            }
        } else {
            images.remove()
        }
        await derived.replanNotifications()
    }

    func setShown(_ isShown: Bool) async {
        await change { $0.habits.showsNotificationPicture = isShown }
    }

    func setUsesHabitColor(_ usesColor: Bool) async {
        await change { $0.habits.notificationUsesHabitColor = usesColor }
    }

    /// The picture is drawn from the settings file: the change is written before the replan.
    private func change(_ edit: (inout AppSettings) -> Void) async {
        settings.update(edit)
        await settings.flush()
        await derived.replanNotifications()
    }
}
