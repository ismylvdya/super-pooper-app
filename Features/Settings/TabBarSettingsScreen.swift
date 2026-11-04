import SwiftUI

/// The tab bar's symbols: each tab's name of an SF Symbol when it is not the current tab and when it is, and the "+"'s. Empty
/// is the app's own. A name that is no symbol shows in red and changes nothing.
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
                row("settings.tabBar.symbol", key: TabBarSymbols.newItemKey)
            }
        }
    }

    private func row(_ title: LocalizedStringKey, key: String) -> some View {
        TabSymbolRow(title: title, key: key)
    }
}

private struct TabSymbolRow: View {
    @Environment(AppModel.self) private var model
    @Environment(\.tokens) private var tokens
    let title: LocalizedStringKey
    let key: String

    var body: some View {
        let text = model.settings.tabBar.symbols[key] ?? ""
        let isValid = text.isEmpty || TabBarSymbols.exists(text)
        PlateRow(icon: nil, title: title) {
            TextField("settings.tabBar.placeholder", text: Binding(get: { text }, set: { value in
                model.updateSettings { $0.tabBar.symbols[key] = value.isEmpty ? nil : value }
            }))
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            .multilineTextAlignment(.trailing)
            .foregroundStyle(tokens.color(isValid ? .secondaryText : .error))
            .accessibilityIdentifier("settings.tabBar.\(key)")
            if !text.isEmpty, isValid { Image(systemName: text).foregroundStyle(tokens.color(.primaryText)) }
        }
    }
}
