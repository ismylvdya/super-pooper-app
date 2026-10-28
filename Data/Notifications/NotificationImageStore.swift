import UIKit

/// The user's own picture for habit notifications: one PNG in the app group, kept on this device. A large photo is
/// scaled down first (a notification shows a small square).
struct NotificationImageStore: Sendable {
    let url: URL
    /// Longest side of the stored picture, in pixels.
    let maxPixels: CGFloat

    var hasImage: Bool { FileManager.default.fileExists(atPath: url.path) }

    func data() -> Data? { try? Data(contentsOf: url) }

    func save(_ data: Data) throws {
        guard let image = UIImage(data: data) else { throw CocoaError(.fileReadCorruptFile) }
        let scale = min(1, maxPixels / max(image.size.width * image.scale, image.size.height * image.scale))
        let size = CGSize(width: image.size.width * image.scale * scale, height: image.size.height * image.scale * scale)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        let png = UIGraphicsImageRenderer(size: size, format: format).pngData { _ in image.draw(in: CGRect(origin: .zero, size: size)) }
        try png.write(to: url, options: .atomic)
    }

    func remove() {
        try? FileManager.default.removeItem(at: url)
    }
}
