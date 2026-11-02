import CoreGraphics

/// Where the "+" stands upright: over the room the system tab bar keeps for its search-role tab. The system draws that
/// room differently by version (`SystemLook.newItemSlot` picks one), so the app's own button is laid over it.
enum NewItemSlot: Equatable {
    /// iOS 18: the last of `count` equal items across a bar `height` tall standing on the bottom of the safe area.
    case lastTab(count: Int, height: CGFloat)
    /// iOS 26: a round bubble `diameter` wide, `inset` from the screen's trailing side and from its bottom.
    case bubble(diameter: CGFloat, inset: CGFloat)

    /// Its frame on a screen of `screen` size whose safe area ends `bottomSafeArea` above the bottom.
    func frame(in screen: CGSize, bottomSafeArea: CGFloat) -> CGRect {
        switch self {
        case .lastTab(let count, let height):
            let width = screen.width / CGFloat(max(count, 1))
            return CGRect(x: screen.width - width, y: screen.height - bottomSafeArea - height, width: width, height: height)
        case .bubble(let diameter, let inset):
            return CGRect(x: screen.width - inset - diameter, y: screen.height - inset - diameter, width: diameter, height: diameter)
        }
    }
}
