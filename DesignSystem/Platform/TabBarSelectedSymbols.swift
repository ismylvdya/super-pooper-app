import SwiftUI
import UIKit

/// Gives the system tab bar's items their selected symbols, by position: the bar draws them itself, in layers, so a symbol
/// is filled exactly where its moving drop covers it.
struct TabBarSelectedSymbols: UIViewRepresentable {
    let symbols: [String]

    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.isUserInteractionEnabled = false
        return view
    }

    func updateUIView(_ view: UIView, context: Context) {
        DispatchQueue.main.async {
            guard let window = view.window, let items = Self.tabBar(in: window)?.items else { return }
            for (item, symbol) in zip(items, symbols) {
                let configuration = item.image?.symbolConfiguration
                item.selectedImage = UIImage(systemName: symbol, withConfiguration: configuration)
            }
        }
    }

    private static func tabBar(in view: UIView) -> UITabBar? {
        if let bar = view as? UITabBar { return bar }
        return view.subviews.lazy.compactMap(tabBar(in:)).first
    }
}
