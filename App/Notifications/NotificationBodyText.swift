import Foundation

/// The words under a notification's title, by what it is about (`notification.<subject>.body` in the String Catalog).
enum NotificationBodyText {
    @Sendable static func text(for subject: PlannedNotification.Subject) -> String {
        L10n.string("notification.\(subject.rawValue).body")
    }
}
