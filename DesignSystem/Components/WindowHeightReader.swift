import SwiftUI
import UIKit

/// Reports the height of the window a view is shown in, inside its safe area: a popover sizes itself against the
/// window it is in. SwiftUI's geometry stops at the presentation, the window does not.
struct WindowHeightReader: UIViewRepresentable {
    let onChange: (CGFloat) -> Void

    func makeUIView(context: Context) -> Probe {
        Probe(onChange: onChange)
    }

    func updateUIView(_ probe: Probe, context: Context) {
        probe.onChange = onChange
    }

    final class Probe: UIView {
        var onChange: (CGFloat) -> Void
        private var reported: CGFloat?

        init(onChange: @escaping (CGFloat) -> Void) {
            self.onChange = onChange
            super.init(frame: .zero)
            isUserInteractionEnabled = false
        }

        @available(*, unavailable)
        required init?(coder: NSCoder) { nil }

        override func didMoveToWindow() {
            super.didMoveToWindow()
            report()
        }

        override func safeAreaInsetsDidChange() {
            super.safeAreaInsetsDidChange()
            report()
        }

        private func report() {
            guard let window else { return }
            let height = window.bounds.inset(by: window.safeAreaInsets).height
            guard height != reported else { return }
            reported = height
            onChange(height)
        }
    }
}
