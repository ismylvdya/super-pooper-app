import UIKit

/// Home Screen quick actions (long press on the app icon). Each item's type is a deep-link host,
/// so `New task` opens `superpooper://new-task`: the new-task page on Today.
final class QuickActionSceneDelegate: NSObject, UIWindowSceneDelegate {
    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        if let item = connectionOptions.shortcutItem { open(item) }
    }

    func windowScene(_ windowScene: UIWindowScene, performActionFor shortcutItem: UIApplicationShortcutItem,
                     completionHandler: @escaping (Bool) -> Void) {
        open(shortcutItem)
        completionHandler(true)
    }

    private func open(_ item: UIApplicationShortcutItem) {
        guard case .success(let container) = AppContainer.shared,
              let url = URL(string: "\(DeepLink.scheme)://\(item.type)") else { return }
        container.router.handle(url)
    }
}
