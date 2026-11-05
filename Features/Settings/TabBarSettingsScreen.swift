import SwiftUI
import UniformTypeIdentifiers

/// The tab bar's symbols: for each tab when it is not the current one and when it is, the name of an SF Symbol or an SVG file
/// of the user's; the "+" has a name alone. Empty is the app's own. A name that is no symbol shows in red and changes nothing.
struct TabBarSettingsScreen: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        PageScaffold(title: L10n.string("settings.tabBar.summary")) {
            ForEach(AppTab.allCases, id: \.self) { tab in
                PlateSection(header: LocalizedStringKey(String("tab.") + tab.rawValue)) {
                    row("settings.tabBar.notCurrent", key: TabBarSymbols.key(tab, isSelected: false))
                    row("settings.tabBar.current", key: TabBarSymbols.key(tab, isSelected: true))
                }
            }
            PlateSection(header: "newItem.title", hint: "settings.tabBar.hint") {
                row("settings.tabBar.symbol", key: TabBarSymbols.newItemKey, takesFile: false)
            }
        }
    }

    private func row(_ title: LocalizedStringKey, key: String, takesFile: Bool = true) -> some View {
        TabSymbolRow(title: title, key: key, takesFile: takesFile)
    }
}

private struct TabSymbolRow: View {
    @Environment(AppModel.self) private var model
    @Environment(\.tokens) private var tokens
    let title: LocalizedStringKey
    let key: String
    var takesFile = true
    @State private var isPicking = false
    @State private var failed = false

    var body: some View {
        let text = model.settings.tabBar.symbols[key] ?? ""
        PlateRow(icon: nil, title: title) {
            if TabBarIconFiles.isFile(text) { file(text) } else { symbol(text) }
        }
        .fileImporter(isPresented: $isPicking, allowedContentTypes: [.svg]) { result in
            guard case .success(let file) = result else { return }
            Task {
                if let name = await model.addTabBarIcon(from: file) { set(name) } else { failed = true }
            }
        }
        .alert("settings.tabBar.svg.failed", isPresented: $failed) { Button("common.ok") {} }
    }

    /// A symbol's name typed in, or a file instead of it.
    @ViewBuilder private func symbol(_ text: String) -> some View {
        let isValid = text.isEmpty || TabBarSymbols.exists(text)
        TextField("settings.tabBar.placeholder", text: Binding(get: { text }, set: { set($0.isEmpty ? nil : $0) }))
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            .multilineTextAlignment(.trailing)
            .foregroundStyle(tokens.color(isValid ? .secondaryText : .error))
            .accessibilityIdentifier("settings.tabBar.\(key)")
        if !text.isEmpty, isValid { Image(systemName: text).foregroundStyle(tokens.color(.primaryText)) }
        if takesFile {
            Button("settings.tabBar.svg") { isPicking = true }
                .buttonStyle(.borderless)
                .accessibilityIdentifier("settings.tabBar.\(key).svg")
        }
    }

    /// The file's picture, tinted as the bar will, and how to take it away.
    @ViewBuilder private func file(_ name: String) -> some View {
        if let picture = TabBarIconFiles.image(name) {
            Image(uiImage: picture)
                .resizable()
                .renderingMode(.template)
                .scaledToFit()
                .frame(width: tokens.bar(.barButton), height: tokens.bar(.barButton))
                .foregroundStyle(tokens.color(.primaryText))
        }
        RemoveButton(label: "settings.tabBar.svg.remove") {
            set(nil)
            TabBarIconFiles.remove(name)
        }
    }

    private func set(_ value: String?) {
        model.updateSettings { $0.tabBar.symbols[key] = value }
    }
}
