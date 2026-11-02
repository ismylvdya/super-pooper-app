import SwiftUI

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
        }
    }
}
