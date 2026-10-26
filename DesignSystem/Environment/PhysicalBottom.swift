import SwiftUI

/// Where the phone's physical bottom (the home indicator) is while it lies sideways: the trailing edge when it is
/// turned with its top to the left, the leading edge the other way round; nil upright. In landscape the app keeps
/// its buttons where they are on the physical screen: the tab bar along the physical bottom, the Today buttons along
/// the physical top.
enum PhysicalBottom {
    /// The edge for the window's orientation (`landscapeRight` = home indicator on the right).
    static func edge(for orientation: UIInterfaceOrientation) -> HorizontalEdge? {
        switch orientation {
        case .landscapeRight: .trailing
        case .landscapeLeft: .leading
        default: nil
        }
    }

    /// The same from the phone's own orientation, which is named the other way round (`landscapeLeft` = turned with
    /// its top to the left, the home indicator on the right).
    static func edge(for orientation: UIDeviceOrientation) -> HorizontalEdge? {
        switch orientation {
        case .landscapeLeft: .trailing
        case .landscapeRight: .leading
        default: nil
        }
    }

    /// The turn that keeps an arrow pointing the same physical way ("<" points down with the bottom on the right).
    static func arrowTurn(_ bottom: HorizontalEdge?) -> Angle {
        switch bottom {
        case .trailing: .degrees(-90)
        case .leading: .degrees(90)
        case nil: .zero
        }
    }

    /// Items laid out along the physical left-to-right direction, top to bottom on screen: the physical left is
    /// at the bottom while the physical bottom is on the right.
    static func physicalOrder<Item>(_ items: [Item], bottom: HorizontalEdge?) -> [Item] {
        bottom == .trailing ? items.reversed() : items
    }
}

private struct PhysicalBottomKey: EnvironmentKey {
    static let defaultValue: HorizontalEdge? = nil
}

extension EnvironmentValues {
    /// Set by the root view from the window's orientation.
    var physicalBottom: HorizontalEdge? {
        get { self[PhysicalBottomKey.self] }
        set { self[PhysicalBottomKey.self] = newValue }
    }
}
