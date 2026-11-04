import SwiftUI
import UIKit

/// Gives the system tab bar's items the symbols typed for their selected state, by position; it draws them itself, under its
/// moving drop. Items with none keep the system's own.
struct TabBarSelectedSymbols: UIViewRepresentable {
    let symbols: [String?]

    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.isUserInteractionEnabled = false
        return view
    }

    func updateUIView(_ view: UIView, context: Context) {
        DispatchQueue.main.async {
            guard let window = view.window, let items = Self.tabBar(in: window)?.items else { return }
            for (item, symbol) in zip(items, symbols) {
                guard let symbol else { continue }
                item.selectedImage = UIImage(systemName: symbol)
            }
        }
    }

    private static func tabBar(in view: UIView) -> UITabBar? {
        if let bar = view as? UITabBar { return bar }
        return view.subviews.lazy.compactMap(tabBar(in:)).first
    }
}
