import UIKit
import UserNotifications

/// The picture at the right of a habit notification: the user's own picture when there is one, otherwise the habit
/// symbol in the habits' color of the settings, or in the habit's own color when the settings say so. Each notification gets its own file: the
/// system moves an attachment's file into its store.
struct NotificationIcon: @unchecked Sendable {
    let symbolName: String
    /// The habits' color as the settings have it now.
    let color: @Sendable () -> UIColor
    /// Whether habit notifications have a picture at all (the settings now).
    let isShown: @Sendable () -> Bool
    /// Whether a habit's own color wins over the habits' color (the settings now).
    let usesHabitColor: @Sendable () -> Bool
    let pointSize: CGFloat
    let image: NotificationImageStore

    func attachment(habitColor hex: String?) -> UNNotificationAttachment? {
        guard isShown() else { return nil }
        let own = usesHabitColor() ? hex.flatMap { UIColor(hex: $0) } : nil
        guard let data = image.data() ?? symbolPNG(color: own ?? color()) else { return nil }
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".png")
        guard (try? data.write(to: url)) != nil else { return nil }
        return try? UNNotificationAttachment(identifier: "icon", url: url)
    }

    private func symbolPNG(color: UIColor) -> Data? {
        let configuration = UIImage.SymbolConfiguration(pointSize: pointSize, weight: .semibold)
        guard let symbol = UIImage(systemName: symbolName, withConfiguration: configuration)?
            .withTintColor(color, renderingMode: .alwaysOriginal) else { return nil }
        return UIGraphicsImageRenderer(size: symbol.size).image { _ in symbol.draw(at: .zero) }.pngData()
    }
}
