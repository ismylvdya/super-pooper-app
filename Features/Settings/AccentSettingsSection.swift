import SwiftUI

/// The accent color and which kinds of elements take it.
struct AccentSettingsSection: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        PlateSection(header: "settings.accent", hint: "settings.accent.hint") {
            PlateRow(icon: nil, title: "settings.accent.color") {
                ThemeColorField(token: .accentPick)
            }
            ForEach(AccentCategory.allCases, id: \.self) { category in
                PlateRow(icon: nil, title: LocalizedStringKey(String("settings.accent.") + category.rawValue)) {
                    SwitchToggle(isOn: binding(of: category)) { Text(LocalizedStringKey(String("settings.accent.") + category.rawValue)) }
                        .labelsHidden()
                        .accessibilityIdentifier("settings.accent.\(category.rawValue)")
                }
            }
        }
    }

    private func binding(of category: AccentCategory) -> Binding<Bool> {
        Binding(get: { model.settings.accent.categories.contains(category.rawValue) },
                set: { isOn in
                    model.updateSettings { settings in
                        settings.accent.categories.removeAll { $0 == category.rawValue }
                        if isOn { settings.accent.categories.append(category.rawValue) }
                    }
                })
    }
}
