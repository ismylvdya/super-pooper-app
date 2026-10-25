import SwiftUI

@main
struct SuperPooperApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        WindowGroup {
            switch AppContainer.shared {
            case .success(let container):
                RootView(container: container)
            case .failure(let error):
                ConfigErrorView(error: error)
            }
        }
        .backgroundTask(.appRefresh(BackgroundRefresh.identifier)) {
            await BackgroundRefresh.run()
        }
    }
}

/// Shown instead of the app when a bundled config file is broken: names the file and the key. Plain system
/// styles, since the broken file may be tokens.json itself.
struct ConfigErrorView: View {
    let error: ConfigError

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("config.error.title").font(.title2.bold())
            Text(error.description).font(.body.monospaced()).textSelection(.enabled)
            Text("config.error.hint").font(.footnote).foregroundStyle(.secondary)
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}
