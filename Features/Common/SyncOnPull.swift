import SwiftUI

extension View {
    /// Pulling the scroll down syncs everything and says so; `then` reloads what the screen shows on top of the sync
    /// (a list's own tasks).
    func syncsOnPull(then: (@MainActor () async -> Void)? = nil) -> some View {
        modifier(SyncOnPull(then: then))
    }
}

private struct SyncOnPull: ViewModifier {
    @Environment(AppModel.self) private var model
    let then: (@MainActor () async -> Void)?

    func body(content: Content) -> some View {
        content.refreshable {
            await model.sync(announce: true)
            await then?()
        }
    }
}
