import SwiftUI
import UIKit
/// The icon of the button to the lists, picked by name from `lists.json` → `icons`; the row shows the one picked.
struct ListsSettingsSection: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        PlateSection(header: "settings.lists") {
            PlateRow(icon: model.listsIcon, title: "settings.listsIcon") {
                Picker("settings.listsIcon", selection: Binding(
                    get: { model.settings.lists.icon },
                    set: { value in
                        Haptics.play(.select)
                        model.updateSettings { $0.lists.icon = value }
                    }
                )) {
                    ForEach(model.config.lists.icons) { choice in
                        Text(LocalizedStringKey(choice.title)).tag(choice.id)
                    }
                }
                .labelsHidden()
                .accessibilityIdentifier("settings.listsIcon")
            }
            ForEach(TaskListIcons.editable, id: \.name) { list in
                ListSymbolRow(title: LocalizedStringKey(list.title), key: list.name.rawValue)
            }
            PlateRow(icon: nil, title: "settings.lists.needsPull", info: "info.settings.lists.needsPull") {
                SwitchToggle("settings.lists.needsPull", isOn: Binding(get: { model.settings.lists.needsPull },
                                                                       set: { value in model.updateSettings { $0.lists.needsPull = value } }))
                    .labelsHidden()
                    .accessibilityIdentifier("settings.lists.needsPull")
            }
        }
    }
}

/// A list's icon, by the name of an SF Symbol; empty is the app's own. A name that is no symbol shows in red and changes nothing.
private struct ListSymbolRow: View {
    @Environment(AppModel.self) private var model
    @Environment(\.tokens) private var tokens
    let title: LocalizedStringKey
    let key: String

    var body: some View {
        let text = model.settings.lists.symbols[key] ?? ""
        let isValid = text.isEmpty || UIImage(systemName: text) != nil
        PlateRow(icon: nil, title: title) {
            TextField("settings.tabBar.placeholder", text: Binding(get: { text }, set: { value in
                model.updateSettings { $0.lists.symbols[key] = value.isEmpty ? nil : value }
            }))
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            .multilineTextAlignment(.trailing)
            .foregroundStyle(tokens.color(isValid ? .secondaryText : .error))
            .accessibilityIdentifier("settings.lists.symbol.\(key)")
            if !text.isEmpty, isValid { Image(systemName: text).foregroundStyle(tokens.color(.primaryText)) }
        }
    }
}
