import UIKit

/// The label of a row's swipe button: the action's symbol with its title under it, drawn as one template image. The
/// system lays a swipe button's `Label` out by the row's height (title inside the button on a tall row, under it on a
/// short one, D-089); an image alone it always draws inside, so every list's buttons look alike.
@MainActor
enum SwipeButtonGlyph {
    private static var drawn: [String: UIImage] = [:]

    static func image(symbol: String, title: String, iconFont: UIFont, titleFont: UIFont, gap: CGFloat, scale: CGFloat) -> UIImage {
        let key = [symbol, title, iconFont.fontName, "\(iconFont.pointSize)", titleFont.fontName, "\(titleFont.pointSize)", "\(gap)", "\(scale)"]
            .joined(separator: "|")
        if let cached = drawn[key] { return cached }
        let icon = UIImage(systemName: symbol, withConfiguration: UIImage.SymbolConfiguration(font: iconFont))?
            .withTintColor(.black, renderingMode: .alwaysOriginal)
        let text = NSAttributedString(string: title, attributes: [.font: titleFont, .foregroundColor: UIColor.black])
        let iconSize = icon?.size ?? .zero
        let textSize = text.size()
        let size = CGSize(width: ceil(max(iconSize.width, textSize.width)), height: ceil(iconSize.height + gap + textSize.height))
        let format = UIGraphicsImageRendererFormat.preferred()
        format.scale = scale
        let image = UIGraphicsImageRenderer(size: size, format: format).image { _ in
            icon?.draw(at: CGPoint(x: (size.width - iconSize.width) / 2, y: 0))
            text.draw(at: CGPoint(x: (size.width - textSize.width) / 2, y: iconSize.height + gap))
        }
        .withRenderingMode(.alwaysTemplate)
        drawn[key] = image
        return image
    }
}
