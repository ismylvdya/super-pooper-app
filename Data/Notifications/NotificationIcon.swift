import UIKit
import UserNotifications

/// The picture at the right of a habit notification: the user's own picture when there is one, otherwise the habit
/// symbol in the habits' color of the settings (the same for every habit). Each notification gets its own file: the
/// system moves an attachment's file into its store.
struct NotificationIcon: @unchecked Sendable {
    let symbolName: String
    /// The habits' color as the settings have it now.
    let color: @Sendable () -> UIColor
    let pointSize: CGFloat
    let image: NotificationImageStore

    func attachment() -> UNNotificationAttachment? {
        guard let data = image.data() ?? symbolPNG() else { return nil }
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".png")
        guard (try? data.write(to: url)) != nil else { return nil }
        return try? UNNotificationAttachment(identifier: "icon", url: url)
    }

    private func symbolPNG() -> Data? {
        let configuration = UIImage.SymbolConfiguration(pointSize: pointSize, weight: .semibold)
        guard let symbol = UIImage(systemName: symbolName, withConfiguration: configuration)?
            .withTintColor(color(), renderingMode: .alwaysOriginal) else { return nil }
        return UIGraphicsImageRenderer(size: symbol.size).image { _ in symbol.draw(at: .zero) }.pngData()
    }
}
