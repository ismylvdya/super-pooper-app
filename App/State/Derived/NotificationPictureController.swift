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

    @discardableResult
    func setShown(_ isShown: Bool) -> Task<Void, Never> {
        change { $0.habits.showsNotificationPicture = isShown }
    }

    @discardableResult
    func setUsesHabitColor(_ usesColor: Bool) -> Task<Void, Never> {
        change { $0.habits.notificationUsesHabitColor = usesColor }
    }

    /// The setting shows at once. The picture is drawn from the settings file: the change is written before the replan
    /// (the returned work).
    private func change(_ edit: (inout AppSettings) -> Void) -> Task<Void, Never> {
        settings.update(edit)
        return Task {
            await settings.flush()
            await derived.replanNotifications()
        }
    }
}
