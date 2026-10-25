import SwiftUI

/// The pool rules in priority order: drag to change which rule decides first; the order is saved in the
/// settings and used by Today and the widget. Reset brings back `sort.json`.
struct PoolOrderScreen: View {
    @Environment(AppModel.self) private var model
    @Environment(\.tokens) private var tokens

    var body: some View {
        let criteria = DayPlanning.sortCriteria(config: model.config, settings: model.settings)
        List {
            Section {
                ForEach(criteria, id: \.self) { criterion in
                    TitleDetailLabel(detail: Text(LocalizedStringKey(String("sort.") + criterion.rawValue + ".hint"))) {
                        Text(LocalizedStringKey(String("sort.") + criterion.rawValue))
                    }
                    .listRowBackground(tokens.color(.plateBackground))
                }
                .onMove { source, destination in
                    var names = criteria.map(\.rawValue)
                    names.move(fromOffsets: source, toOffset: destination)
                    Haptics.play(.medium)
                    model.updateSettings { $0.pool.criteria = names }
                }
            } footer: {
                Text("sort.footer")
            }
            Section {
                Button("sort.reset") { model.updateSettings { $0.pool.criteria = [] } }
                    .disabled(model.settings.pool.criteria.isEmpty)
                    .listRowBackground(tokens.color(.plateBackground))
            }
        }
        .scrollContentBackground(.hidden)
        .background(tokens.color(.screenBackground))
        .navigationTitle(Text("sort.title"))
        .navigationBarTitleDisplayMode(.inline)
    }
}
