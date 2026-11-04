import SwiftUI
import UIKit

/// Shows or hides the round bubble the system tab bar draws for its search-role tab, keeping the bar's layout as it is
/// (taking the tab away would make the bar grow). The bubble is the bar's own round direct subview at its trailing end;
/// where the system lays the bar out otherwise, nothing is found and nothing changes.
struct SearchTabBubbleVisibility: UIViewRepresentable {
    let isVisible: Bool

    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.isUserInteractionEnabled = false
        return view
    }

    func updateUIView(_ view: UIView, context: Context) {
        guard let window = view.window, let bar = Self.tabBar(in: window) else { return }
        Self.bubble(in: bar)?.alpha = isVisible ? 1 : 0
    }

    private static func tabBar(in view: UIView) -> UITabBar? {
        if let bar = view as? UITabBar { return bar }
        return view.subviews.lazy.compactMap(tabBar(in:)).first
    }

    static func bubble(in bar: UIView) -> UIView? {
        bar.subviews
            .filter { abs($0.bounds.width - $0.bounds.height) < 1 && $0.bounds.width > 0 }
            .max { $0.frame.maxX < $1.frame.maxX }
    }
}
