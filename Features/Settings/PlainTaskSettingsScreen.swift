import SwiftUI

/// The color settings for plain tasks.
struct PlainTaskSettingsScreen: View {
    @Environment(\.tokens) private var tokens

    var body: some View {
        PageScaffold(title: L10n.string("settings.plainTasks.summary")) {
            PlateSection(header: "settings.colors") {
                ForEach(tokens.editableColors[.tasks], id: \.self) { token in
                    PlateRow(icon: nil, title: LocalizedStringKey(String("color.") + token.rawValue)) { ThemeColorField(token: token) }
                }
            }
        }
    }
}
