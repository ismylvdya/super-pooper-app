import Foundation

extension AppModel {
    /// The user's own picture for habit notifications (this device), or nil for the habit symbol.
    var notificationImageData: Data? { services.notificationImage.data() }

    /// Sets (or with nil removes) the picture; notifications planned from now on carry it.
    func setNotificationImage(_ data: Data?) async {
        if let data {
            do {
                try services.notificationImage.save(data)
            } catch {
                banners.show(L10n.string("banner.notificationImageFailed"), style: .warning)
                return
            }
        } else {
            services.notificationImage.remove()
        }
        await rescheduleNotifications(context: context())
    }
}
