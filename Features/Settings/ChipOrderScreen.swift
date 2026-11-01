import SwiftUI

/// The order of the property chips in task rows: drag to change it; saved in the settings. Reset brings back the
/// order from `defaults.json`.
struct ChipOrderScreen: View {
    @Environment(AppModel.self) private var model
    @Environment(\.tokens) private var tokens
    @Environment(\.icons) private var icons

    var body: some View {
        let kinds = RowChipKind.ordered(model.settings.pool.chipOrder)
        List {
            Section {
                ForEach(kinds, id: \.self) { kind in
                    HStack(spacing: tokens.space(.iconTextGap)) {
                        HStack(spacing: tokens.space(.chipGap)) {
                            ForEach(kind.looks, id: \.self) { look in
                                Image(systemName: icons[look.icon]).foregroundStyle(tokens.color(of: look))
                            }
                        }
                        Text(LocalizedStringKey(String("chipOrder.") + kind.rawValue))
                    }
                    .listRowBackground(tokens.color(.plateBackground))
                }
                .onMove { source, destination in
                    var names = kinds.map(\.rawValue)
                    names.move(fromOffsets: source, toOffset: destination)
                    Haptics.play(.reorder)
                    model.updateSettings { $0.pool.chipOrder = names }
                }
            } footer: {
                Text("chipOrder.footer")
            }
            Section {
                Button("chipOrder.reset") {
                    model.updateSettings { $0.pool.chipOrder = defaultOrder }
                }
                .disabled(kinds == RowChipKind.ordered(defaultOrder))
                .listRowBackground(tokens.color(.plateBackground))
            }
        }
        .appList()
        .navigationTitle(Text("chipOrder.title"))
        .navigationBarTitleDisplayMode(.inline)
    }

    private var defaultOrder: [String] {
        model.config.defaultSettings.values.pool.chipOrder
    }
}
