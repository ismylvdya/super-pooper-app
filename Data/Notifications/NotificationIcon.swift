import UIKit
import UserNotifications

/// The picture at the right of a habit notification: the habit symbol in the habit's own color (or the habit color
/// of the settings). Each notification gets its own file: the system moves an attachment's file into its store.
struct NotificationIcon: @unchecked Sendable {
    let symbolName: String
    let defaultColor: UIColor
    let pointSize: CGFloat

    func attachment(colorHex: String?) -> UNNotificationAttachment? {
        let color = colorHex.flatMap { UIColor(hex: $0) } ?? defaultColor
        let configuration = UIImage.SymbolConfiguration(pointSize: pointSize, weight: .semibold)
        guard let symbol = UIImage(systemName: symbolName, withConfiguration: configuration)?
            .withTintColor(color, renderingMode: .alwaysOriginal),
              let data = UIGraphicsImageRenderer(size: symbol.size).image(actions: { _ in symbol.draw(at: .zero) }).pngData()
        else { return nil }
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".png")
        guard (try? data.write(to: url)) != nil else { return nil }
        return try? UNNotificationAttachment(identifier: "icon", url: url)
    }
}
