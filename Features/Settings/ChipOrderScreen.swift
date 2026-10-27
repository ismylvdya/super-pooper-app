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
                            ForEach(Self.icons(of: kind), id: \.self) { icon in
                                Image(systemName: icons[icon]).foregroundStyle(tint(icon))
                            }
                        }
                        Text(LocalizedStringKey(String("chipOrder.") + kind.rawValue))
                    }
                    .listRowBackground(tokens.color(.plateBackground))
                }
                .onMove { source, destination in
                    var names = kinds.map(\.rawValue)
                    names.move(fromOffsets: source, toOffset: destination)
                    Haptics.play(.medium)
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
        (try? JSONDecoder.store.decode(AppSettings.self, from: model.config.defaultSettings))?.pool.chipOrder ?? []
    }

    /// The symbols a chip of this kind can show.
    private static func icons(of kind: RowChipKind) -> [Icon] {
        switch kind {
        case .problem: [.problem]
        case .blocked: [.links]
        case .high: [.high]
        case .feel: [.energy, .pleasant]
        case .habit: [.habit]
        }
    }

    private func tint(_ icon: Icon) -> Color {
        switch icon {
        case .problem: tokens.color(.problem)
        case .high: tokens.color(.high)
        case .energy: tokens.color(.energy)
        case .pleasant: tokens.color(.heart)
        case .habit: tokens.color(.habit)
        default: tokens.color(.secondaryText)
        }
    }
}
