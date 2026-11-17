import SwiftUI
import UIKit

/// Gives the system tab bar's items their selected symbols, by position: the bar draws them itself, in layers, so a symbol
/// is filled exactly where its moving drop covers it.
struct TabBarSelectedSymbols: UIViewRepresentable {
    let symbols: [String]
    /// What stands for a name that is no symbol: a glyph's or an added file's picture.
    let glyph: (String) -> UIImage?

    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.isUserInteractionEnabled = false
        return view
    }

    /// What was last given to the bar: a redraw that would give the same items the same symbols leaves them alone (the
    /// bar redraws on every new image).
    final class Coordinator {
        var symbols: [String] = []
        var images: [UIImage?] = []
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    func updateUIView(_ view: UIView, context: Context) {
        let coordinator = context.coordinator
        DispatchQueue.main.async {
            guard let window = view.window, let items = Self.tabBar(in: window)?.items else { return }
            let given = coordinator.symbols == symbols && items.count == coordinator.images.count
                && zip(items, coordinator.images).allSatisfy { $0.selectedImage === $1 }
            guard !given else { return }
            coordinator.images = zip(items, symbols).map { item, symbol in
                let configuration = item.image?.symbolConfiguration
                item.selectedImage = UIImage(systemName: symbol, withConfiguration: configuration) ?? glyph(symbol)
                return item.selectedImage
            }
            coordinator.symbols = symbols
        }
    }

    private static func tabBar(in view: UIView) -> UITabBar? {
        if let bar = view as? UITabBar { return bar }
        return view.subviews.lazy.compactMap(tabBar(in:)).first
    }
}
