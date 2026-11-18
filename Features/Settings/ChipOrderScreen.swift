import ListEngineChumbulev
import SwiftUI

/// The order of the property chips in task rows: drag to change it; saved in the settings. Reset brings back the
/// order from `defaults.json`. A list of the list engine, rows carried only.
struct ChipOrderScreen: View {
    @Environment(AppModel.self) private var model
    @Environment(\.tokens) private var tokens

    var body: some View {
        let kinds = RowChipKind.ordered(model.settings.pool.chipOrder)
        ReorderableList(sections: Binding(get: { .single(kinds.map { OrderedRow(id: $0.rawValue) }) },
                                          set: { sections in model.updateSettings { $0.pool.chipOrder = sections.flatMap(\.items).map(\.id) } }),
                        look: "lists", features: .orderOnly,
                        footer: AnyView(OrderFooter(hint: "chipOrder.footer", reset: "chipOrder.reset",
                                                    canReset: kinds != RowChipKind.ordered(defaultOrder)) {
                            model.updateSettings { $0.pool.chipOrder = defaultOrder }
                        })) { row in
            if let kind = RowChipKind(rawValue: row.id) {
                HStack(spacing: tokens.space(.iconTextGap)) {
                    HStack(spacing: tokens.space(.chipGap)) {
                        ForEach(kind.looks, id: \.self) { look in
                            IconGlyph(look.icon, font: .rowTitle).foregroundStyle(tokens.color(of: look))
                        }
                    }
                    Text(LocalizedStringKey(String("chipOrder.") + kind.rawValue))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .ignoresSafeArea()
        .navigationTitle(Text("chipOrder.title"))
        .navigationBarTitleDisplayMode(.inline)
    }

    private var defaultOrder: [String] {
        model.config.defaultSettings.values.pool.chipOrder
    }
}
