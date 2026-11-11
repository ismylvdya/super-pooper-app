import SwiftUI
import UIKit

extension View {
    /// A hold anywhere on the navigation bar outside its buttons — over the title, small or large, the day's arrows, the
    /// empty room — runs `action` (the page's search), as a hold of a chat's title does in messengers. A tap there works
    /// as before: the hold is a system long press that takes the touch only once held. The page's own large title
    /// (`LargePageTitle`) takes the same hold.
    func searchOnTitleHold(_ action: @escaping () -> Void) -> some View {
        let held = {
            Haptics.play(.select)
            action()
        }
        return background { TitleHoldAnchor(action: held).frame(width: 0, height: 0) }
            .environment(\.titleHold, TitleHoldAction(run: held))
    }
}

/// Finds the page's controller in its navigation stack and gives the bar's hold this page's action.
private struct TitleHoldAnchor: UIViewRepresentable {
    let action: () -> Void

    func makeUIView(context: Context) -> AnchorView { AnchorView() }

    func updateUIView(_ view: AnchorView, context: Context) {
        view.action = action
        view.attach()
    }

    final class AnchorView: UIView {
        var action: (() -> Void)?

        override func didMoveToWindow() {
            super.didMoveToWindow()
            attach()
        }

        func attach() {
            guard window != nil, let action, let page = pageController, let bar = page.navigationController?.navigationBar else { return }
            TitleHoldRecognizer.installed(on: bar).actions.setObject(TitleHoldBox(action), forKey: page)
        }

        /// The controller the navigation stack pushed this page in.
        private var pageController: UIViewController? {
            var responder: UIResponder? = self
            while let next = responder?.next {
                if let controller = next as? UIViewController {
                    var page: UIViewController? = controller
                    while let candidate = page {
                        if let stack = candidate.navigationController, stack.viewControllers.contains(candidate) { return candidate }
                        page = candidate.parent
                    }
                }
                responder = next
            }
            return nil
        }
    }
}

private final class TitleHoldBox {
    let run: () -> Void
    init(_ run: @escaping () -> Void) { self.run = run }
}

/// One long press per navigation bar; it runs the action of the page on top. Touches on the bar's buttons are not its:
/// a held button keeps its own menu or tap.
private final class TitleHoldRecognizer: UILongPressGestureRecognizer, UIGestureRecognizerDelegate {
    let actions = NSMapTable<UIViewController, TitleHoldBox>.weakToStrongObjects()
    private weak var bar: UINavigationBar?

    static func installed(on bar: UINavigationBar) -> TitleHoldRecognizer {
        if let found = bar.gestureRecognizers?.compactMap({ $0 as? TitleHoldRecognizer }).first { return found }
        let recognizer = TitleHoldRecognizer()
        recognizer.bar = bar
        recognizer.addTarget(recognizer, action: #selector(held))
        recognizer.delegate = recognizer
        bar.addGestureRecognizer(recognizer)
        return recognizer
    }

    @objc private func held() {
        guard state == .began, let top = bar?.delegate as? UINavigationController ?? bar.flatMap(Self.stack(of:)),
              let page = top.topViewController, let box = actions.object(forKey: page) else { return }
        box.run()
    }

    private static func stack(of bar: UINavigationBar) -> UINavigationController? {
        var responder: UIResponder? = bar
        while let next = responder?.next {
            if let stack = next as? UINavigationController { return stack }
            responder = next
        }
        return nil
    }

    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldReceive touch: UITouch) -> Bool {
        var view = touch.view
        while let current = view, current !== bar {
            let name = NSStringFromClass(type(of: current))
            // The bar's title is a control of its own; holding it is what this is for.
            if current is UIControl, !name.contains("TitleControl") { return false }
            if name.contains("BarButton") || name.contains("ButtonBar") { return false }
            view = current.superview
        }
        return true
    }

    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer,
                           shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer) -> Bool { true }
}
