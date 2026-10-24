import SwiftUI

/// The order of the morning and evening routines: drag habits within a routine; the pool follows it.
/// Habits join a routine by their part of the day (habit page → Part of the day).
struct RoutinesScreen: View {
    @Environment(AppModel.self) private var model
    @Environment(\.tokens) private var tokens

    var body: some View {
        List {
            section(.morning, title: "routines.morning", keyPath: \.morningRoutine)
            section(.evening, title: "routines.evening", keyPath: \.eveningRoutine)
        }
        .scrollContentBackground(.hidden)
        .background(tokens.color(.screenBackground))
        .navigationTitle(Text("routines.title"))
        .navigationBarTitleDisplayMode(.inline)
    }

    @ViewBuilder
    private func section(_ part: HabitTimeOfDay, title: LocalizedStringKey, keyPath: WritableKeyPath<AppSettings.Habits, [String]>) -> some View {
        let members = HabitRoutines.members(part, of: model.habits, order: model.settings.habits[keyPath: keyPath])
        Section {
            if members.isEmpty {
                Text("routines.empty").font(tokens.font(.hint)).foregroundStyle(tokens.color(.secondaryText))
                    .listRowBackground(tokens.color(.plateBackground))
            }
            ForEach(members, id: \.name) { habit in
                Text(habit.name).foregroundStyle(tokens.habitColor(habit))
                    .listRowBackground(tokens.color(.plateBackground))
            }
            .onMove { source, destination in
                var names = members.map(\.name)
                names.move(fromOffsets: source, toOffset: destination)
                Haptics.play(.medium)
                model.updateSettings { $0.habits[keyPath: keyPath] = names }
            }
        } header: {
            Text(title)
        } footer: {
            Text("routines.hint")
        }
    }
}

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
                    VStack(alignment: .leading, spacing: 2) {
                        Text(LocalizedStringKey(String("sort.") + criterion.rawValue))
                        Text(LocalizedStringKey(String("sort.") + criterion.rawValue + ".hint"))
                            .font(tokens.font(.hint)).foregroundStyle(tokens.color(.secondaryText))
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
