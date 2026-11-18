import ListEngineChumbulev
import SwiftUI

/// The pool rules in priority order: drag to change which rule decides first; the order is saved in the
/// settings and used by Today and the widget. Reset brings back `sort.json`. A list of the list engine, rows carried only.
struct PoolOrderScreen: View {
    @Environment(AppModel.self) private var model
    @Environment(\.tokens) private var tokens

    var body: some View {
        let criteria = DayPlanning.sortCriteria(config: model.config, settings: model.settings)
        ReorderableList(sections: Binding(get: { .single(criteria.map { OrderedRow(id: $0.rawValue) }) },
                                          set: { sections in model.updateSettings { $0.pool.criteria = sections.flatMap(\.items).map(\.id) } }),
                        look: "lists", features: .orderOnly,
                        footer: AnyView(OrderFooter(hint: "sort.footer", reset: "sort.reset", canReset: !model.settings.pool.criteria.isEmpty) {
                            model.updateSettings { $0.pool.criteria = [] }
                        })) { row in
            TitleDetailLabel(detail: Text(LocalizedStringKey(String("sort.") + row.id + ".hint"))) {
                Text(LocalizedStringKey(String("sort.") + row.id))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .ignoresSafeArea()
        .navigationTitle(Text("sort.title"))
        .navigationBarTitleDisplayMode(.inline)
    }
}
